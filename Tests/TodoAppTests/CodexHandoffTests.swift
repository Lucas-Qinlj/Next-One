import XCTest
import AppKit
import CSQLite
import TodoCore
@testable import TodoApp

final class CodexHandoffTests: XCTestCase {
    var root: URL!
    var database: URL { root.appendingPathComponent("codex.sqlite") }
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func sql(_ text: String) throws {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(database.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(sqlite3_exec(db, text, nil, nil, nil), SQLITE_OK)
    }
    func fixture() throws {
        try sql("CREATE TABLE projects(id TEXT, name TEXT, position INTEGER); CREATE TABLE project_roots(project_id TEXT, position INTEGER, path TEXT);")
        try sql("INSERT INTO projects VALUES('p','Project',1); INSERT INTO project_roots VALUES('p',0,'\(root.path)');")
    }
    func store() throws -> Store {
        let store = try Store(directory: root.appendingPathComponent("next-one"))
        _ = try store.execute("add", ["project":"unclassified", "title":"Initial <title>", "description":"Notes &\n</neo>"])
        return store
    }

    func testReadOnlySchemaEmptyMultipleRootsAndExactMatching() throws {
        XCTAssertThrowsError(try CodexProjects.read(database: database))
        XCTAssertFalse(FileManager.default.fileExists(atPath: database.path))
        try fixture()
        try sql("INSERT INTO projects VALUES('q','Project',0); INSERT INTO project_roots VALUES('q',0,'\(root.path)/child'); INSERT INTO project_roots VALUES('p',1,'\(root.path)/other');")
        let before = try Data(contentsOf: database)
        let projects = try CodexProjects.read(database: database)
        XCTAssertEqual(projects.map(\.id), ["q", "p"])
        XCTAssertEqual(projects[1].paths.count, 2)
        XCTAssertEqual(CodexHandoff.matching(root.path + "/", in: projects).map(\.id), ["p"])
        XCTAssertTrue(CodexHandoff.matching(root.path + "/chil", in: projects).isEmpty)
        let alias = root.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: root)
        XCTAssertEqual(CodexHandoff.matching(alias.path, in: projects).map(\.id), ["p"])
        XCTAssertEqual(try Data(contentsOf: database), before)
        try sql("DELETE FROM project_roots; DELETE FROM projects;")
        XCTAssertTrue(try CodexProjects.read(database: database).isEmpty)
        try sql("DROP TABLE projects;")
        XCTAssertThrowsError(try CodexProjects.read(database: database))
    }

    func testLiveWALAndBusyDatabase() throws {
        try fixture()
        var writer: OpaquePointer?
        XCTAssertEqual(sqlite3_open(database.path, &writer), SQLITE_OK)
        defer { sqlite3_close(writer) }
        XCTAssertEqual(sqlite3_exec(writer, "PRAGMA journal_mode=WAL; INSERT INTO projects VALUES('new','New',2); INSERT INTO project_roots VALUES('new',0,'\(root.path)/new');", nil, nil, nil), SQLITE_OK)
        XCTAssertEqual(try CodexProjects.read(database: database).count, 2)
        XCTAssertEqual(sqlite3_exec(writer, "PRAGMA wal_checkpoint(TRUNCATE); PRAGMA journal_mode=DELETE; BEGIN EXCLUSIVE;", nil, nil, nil), SQLITE_OK)
        XCTAssertThrowsError(try CodexProjects.read(database: database))
        sqlite3_exec(writer, "ROLLBACK", nil, nil, nil)
    }

    func testDatabaseLocation() throws {
        XCTAssertEqual(try CodexProjects.databaseURL(environment: [:], home: root).path, root.path + "/.codex/state_5.sqlite")
        XCTAssertEqual(try CodexProjects.databaseURL(environment: ["CODEX_HOME":root.path]).path, database.deletingLastPathComponent().path + "/state_5.sqlite")
        XCTAssertThrowsError(try CodexProjects.databaseURL(environment: ["CODEX_HOME":"relative"]))
    }

    func testReadableEnvelopeAndURLRoundTrip() throws {
        let store = try store(), task = try XCTUnwrap(store.snapshot().liveTasks.first)
        let instruction = "原样 <tag> & + # %\n第二行"
        let message = try CodexHandoff.message(item: task, originPath: root.path + "/source", targetPath: root.path,
                                               attachments: [("图 片.png",root.path + "/a & b.png")], instruction: instruction)
        XCTAssertTrue(message.hasPrefix("<neo>\nA1 Initial &lt;title&gt;\nNotes &amp;\n&lt;/neo&gt;"))
        XCTAssertTrue(message.hasSuffix("</neo>\n\n" + instruction))
        XCTAssertFalse(message.contains(task.id))
        XCTAssertTrue(message.contains("会话项目路径："))
        let url = try CodexHandoff.url(message: message, targetPath: root.path)
        let query = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(query.first { $0.name == "prompt" }?.value, message)
        XCTAssertEqual(query.first { $0.name == "path" }?.value, root.path)
        XCTAssertTrue(url.absoluteString.contains("%2B"))
        let empty = try CodexHandoff.message(item: task, originPath: nil, targetPath: root.path, attachments: [], instruction: "")
        XCTAssertTrue(empty.hasSuffix("</neo>")); XCTAssertFalse(empty.contains("会话项目路径："))
    }

    @MainActor func testSessionUsesFreshTaskPreservesInstructionAndNeverChangesStatus() async throws {
        try fixture(); let store = try store()
        let task = try XCTUnwrap(store.snapshot().liveTasks.first)
        let session = CodexHandoffSession(taskID: task.id, store: store, database: database)
        await session.reload()
        XCTAssertEqual(session.step, .project)
        session.chooseProject(try XCTUnwrap(session.projects.first))
        XCTAssertEqual(session.step, .prompt)
        session.instruction = "custom\ntext"
        _ = try store.execute("update", ["id":task.id,"title":"Updated","expected-revision":"1"])
        let model = AppModel(store: store)
        model.codexHandoff = session
        await model.prepareCodexHandoff(session)
        XCTAssertNil(model.codexHandoff)
        XCTAssertNotNil(model.pendingCodexHandoff)
        session.cancelled = true // The disappearing sheet cancels further preparation.
        var opened: URL?
        model.finishCodexHandoff { opened = $0; return false }
        XCTAssertTrue(model.codexHandoff === session)
        XCTAssertFalse(session.cancelled)
        XCTAssertNotNil(session.error)
        XCTAssertEqual(session.instruction,"custom\ntext")
        let message = URLComponents(url: try XCTUnwrap(opened), resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "prompt" }?.value
        XCTAssertTrue(message?.contains("A1 Updated") == true)
        XCTAssertEqual(try store.snapshot().liveTasks.first?.status,"todo")
        session.cancelled = true
        let cancelled = await session.prepareOpen()
        XCTAssertNil(cancelled)
        try sql("DELETE FROM project_roots")
        do { _ = try await session.prepareURL(); XCTFail() } catch {}
    }

    @MainActor func testHandoffHidesPanelBeforeOpenAndRestoresOnFailure() async throws {
        try fixture(); let store = try store()
        let task = try XCTUnwrap(store.snapshot().liveTasks.first)
        let model = AppModel(store: store)
        let controller = FloatingController(model: model)
        defer {
            controller.timer?.invalidate(); controller.lockHoverTimer?.invalidate()
            controller.panel.orderOut(nil); controller.ball.orderOut(nil)
            NSStatusBar.system.removeStatusItem(controller.statusItem)
        }
        let session = CodexHandoffSession(taskID: task.id, store: store, database: database)
        await session.reload()
        session.chooseProject(try XCTUnwrap(session.projects.first))
        session.instruction = "preserve draft"
        model.codexHandoff = session
        await model.prepareCodexHandoff(session)
        XCTAssertTrue(controller.panel.isVisible) // Validation must not hide the panel.
        var count = 0
        model.finishCodexHandoff { _ in
            count += 1
            XCTAssertFalse(controller.panel.isVisible)
            XCTAssertFalse(controller.expanded)
            XCTAssertTrue(controller.ball.isVisible)
            return false
        }
        XCTAssertTrue(controller.panel.isVisible)
        XCTAssertTrue(controller.expanded)
        XCTAssertTrue(model.codexHandoff === session)
        XCTAssertEqual(session.instruction, "preserve draft")
        XCTAssertNotNil(session.error)
        await model.prepareCodexHandoff(session)
        model.finishCodexHandoff { _ in count += 1; return true }
        XCTAssertFalse(controller.panel.isVisible)
        XCTAssertFalse(controller.expanded)
        XCTAssertTrue(controller.ball.isVisible)
        XCTAssertNil(model.codexHandoff)
        model.finishCodexHandoff { _ in XCTFail("Duplicate open"); return true }
        XCTAssertEqual(count, 2)
        controller.toggle()
        XCTAssertTrue(controller.panel.isVisible)
    }

    @MainActor func testSingleAndMultipleSourcePathsAndUnmatchedFallback() async throws {
        try fixture(); let store = try store()
        _ = try store.execute("project bind", ["path":root.path])
        let project = try XCTUnwrap(store.snapshot().projects.first)
        let task = try XCTUnwrap(store.snapshot().liveTasks.first)
        _ = try store.execute("move", ["id":task.id,"project":project.id,"expected-revision":"1"])
        let session = CodexHandoffSession(taskID: task.id, store: store, database: database)
        await session.reload(); XCTAssertEqual(session.step,.prompt)
        _ = try store.execute("project bind", ["project":project.id,"path":root.appendingPathComponent("next-one").path,"expected-revision":String(project.revision)])
        await session.reload(); XCTAssertEqual(session.step,.sourcePath)
        session.chooseSource(root.appendingPathComponent("next-one").path)
        XCTAssertEqual(session.step,.project)
        session.chooseProject(try XCTUnwrap(session.projects.first))
        XCTAssertEqual(session.step,.prompt)
        let url = try await session.prepareURL()
        XCTAssertTrue(URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems?.first { $0.name == "prompt" }?.value?.contains("会话项目路径：") == true)
    }

    @MainActor func testMissingFocusPermissionKeepsDraftAndDoesNotQueueOpen() async throws {
        try fixture(); let store = try store()
        let task = try XCTUnwrap(store.snapshot().liveTasks.first)
        let model = AppModel(store: store)
        let session = CodexHandoffSession(taskID: task.id, store: store, database: database)
        await session.reload(); session.chooseProject(try XCTUnwrap(session.projects.first))
        session.instruction = "Do not send automatically"
        model.codexHandoff = session; model.codexAutoFocus = true
        await model.prepareCodexHandoff(session, permissionGranted: { false })
        XCTAssertTrue(model.codexHandoff === session)
        XCTAssertNil(model.pendingCodexHandoff)
        XCTAssertTrue(session.needsFocusPermission)
        XCTAssertNotNil(session.error)
        XCTAssertEqual(session.instruction, "Do not send automatically")
        XCTAssertEqual(session.targetPath, root.path)
        model.finishCodexHandoff { _ in XCTFail("Opened without permission"); return true }
        await model.prepareCodexHandoff(session, permissionGranted: { true })
        XCTAssertFalse(session.needsFocusPermission)
        XCTAssertNil(session.error)
        XCTAssertNotNil(model.pendingCodexHandoff)
        // Do not execute the live accessibility client in tests.
        model.codexAutoFocus = false
        model.finishCodexHandoff { _ in true }
    }

    @MainActor func testAttachmentPathsMissingFileAndDeletedTask() async throws {
        try fixture(); let store = try store()
        let task = try XCTUnwrap(store.snapshot().liveTasks.first)
        let file = root.appendingPathComponent("sample.png")
        try Data([0x89,0x50,0x4e,0x47]).write(to:file)
        _ = try store.execute("attachment add", ["id":task.id,"path":file.path,"expected-revision":"1"])
        let session = CodexHandoffSession(taskID:task.id,store:store,database:database)
        await session.reload(); session.chooseProject(try XCTUnwrap(session.projects.first))
        let snapshot = try store.snapshot()
        let attachment = try XCTUnwrap(snapshot.attachments.first)
        let stored = store.attachmentURL(attachment)
        let url = try await session.prepareURL()
        XCTAssertTrue(URLComponents(url:url,resolvingAgainstBaseURL:false)?.queryItems?.first { $0.name == "prompt" }?.value?.contains(stored.path) == true)
        try FileManager.default.removeItem(at:stored)
        do { _ = try await session.prepareURL(); XCTFail("Missing attachment accepted") } catch {}
        _ = try store.execute("delete", ["id":task.id,"expected-revision":String(try XCTUnwrap(snapshot.liveTasks.first).revision)])
        do { _ = try await session.prepareURL(); XCTFail("Deleted task accepted") } catch {}
    }

    @MainActor func testMarkedTextReturnShiftReturnEscapeAndLogo() throws {
        let view = HandoffTextView(frame:NSRect(x:0,y:0,width:300,height:100))
        var submitted = 0, cancelled = 0
        view.submit = { submitted += 1 }; view.cancel = { cancelled += 1 }
        func key(_ code: UInt16, _ flags: NSEvent.ModifierFlags = []) throws -> NSEvent {
            try XCTUnwrap(NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:flags,timestamp:0,windowNumber:0,context:nil,characters:"\r",charactersIgnoringModifiers:"\r",isARepeat:false,keyCode:code))
        }
        view.keyDown(with:try key(36)); XCTAssertEqual(submitted,1)
        view.keyDown(with:try key(36,.shift)); XCTAssertEqual(submitted,1); XCTAssertEqual(view.string,"\n")
        view.setMarkedText("中文", selectedRange:NSRange(location:2,length:0), replacementRange:NSRange(location:NSNotFound,length:0))
        XCTAssertTrue(view.hasMarkedText())
        view.keyDown(with:try key(36)); XCTAssertEqual(submitted,1)
        view.unmarkText(); view.keyDown(with:try key(53)); XCTAssertEqual(cancelled,1)
        XCTAssertFalse(ChatGPTMenuIcon.image.isTemplate)
        XCTAssertEqual(ChatGPTMenuIcon.image.size,NSSize(width:16,height:16))
    }
}
