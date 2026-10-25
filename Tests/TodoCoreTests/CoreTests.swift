import XCTest
import Foundation
import CoreGraphics
@testable import TodoCore

final class CoreTests: XCTestCase {
    var directory: URL!
    var store: Store!
    override func setUpWithError() throws { directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); store = try Store(directory: directory) }
    override func tearDownWithError() throws { store = nil; try FileManager.default.removeItem(at: directory) }
    func call(_ command: String, _ args: [String: String]) throws -> [String: Any] { try store.execute(command, args) }
    func add(_ title: String = "任务", parent: String? = nil, project: String = "unclassified", extra: [String: String] = [:]) throws -> TodoItem {
        var args = ["title": title]; if let parent { args["parent"] = parent } else { args["project"] = project }; args.merge(extra) { _, b in b }
        let value = try call("add", args)["task"] as! [String: Any]; return try task(value["id"] as! String)
    }
    func task(_ id: String) throws -> TodoItem { try XCTUnwrap(store.snapshot().tasks.first { $0.id == id }) }
    func mutate(_ cmd: String, _ id: String, _ extra: [String: String] = [:]) throws {
        var args = ["id": id, "expected-revision": String(try task(id).revision)]; args.merge(extra) { _, b in b }; _ = try call(cmd, args)
    }
    func fails(_ code: String, _ action: () throws -> Void) { XCTAssertThrowsError(try action()) { XCTAssertEqual(($0 as? TodoError)?.code, code) } }
    func project(_ suffix: String) throws -> String {
        let path = directory.appendingPathComponent(suffix); try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
        return (try call("project bind", ["path": path.path])["project"] as! [String: Any])["id"] as! String
    }
    func testPathBoundariesAliasesAndNestedResolution() throws {
        let p = try project("app"), nested = try project("app/nested")
        let r = try call("context", ["cwd": directory.appendingPathComponent("app/nested/child").path])
        XCTAssertEqual((r["project"] as? [String: Any])?["id"] as? String, nested)
        fails("project_unmatched") { _ = try self.call("context", ["cwd": self.directory.appendingPathComponent("apple").path]) }
        let alias = directory.appendingPathComponent("alias"); try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: directory.appendingPathComponent("app"))
        XCTAssertEqual((try call("context", ["cwd": alias.path])["project"] as? [String: Any])?["id"] as? String, p)
        fails("invalid_field") { _ = try self.call("project bind", ["path": alias.path]) }
        try FileManager.default.removeItem(at: directory.appendingPathComponent("app"))
        XCTAssertEqual(try store.snapshot().projects.count, 2)
    }
    func testPersistenceValidationDatesAndPartialUpdates() throws {
        let a = try add("  保留标题  ", extra: ["description": "多行\n描述", "priority": "high", "color": "blue", "due-date": "2026-10-24", "source": "codex"])
        XCTAssertEqual(a.title, "保留标题")
        let reopened = try Store(directory: directory); XCTAssertEqual(try reopened.snapshot().tasks.first, a)
        try mutate("update", a.id, ["status": "in_progress"])
        let updated = try task(a.id); XCTAssertEqual(updated.description, a.description); XCTAssertEqual(updated.createdAt, a.createdAt); XCTAssertEqual(updated.source, "codex")
        fails("invalid_field") { _ = try self.add(" \n ") }
        fails("invalid_field") { try self.mutate("update", a.id, ["due-date": "2026-02-30"]) }
        fails("invalid_field") { try self.mutate("update", a.id, ["due-at": "2026-10-24T10:00:00"]) }
        fails("invalid_field") { try self.mutate("update", a.id, ["source": "user"]) }
        try mutate("update", a.id, ["due-at": "2026-10-24T12:00:00+08:00"])
        XCTAssertEqual(try task(a.id).dueAt, "2026-10-24T04:00:00Z"); XCTAssertNil(try task(a.id).dueDate)
        XCTAssertEqual(try store.snapshot().tasks.count, 1)
    }
    func testDepthCyclesCrossProjectAndAtomicBranchMove() throws {
        let p = try project("p"), q = try project("q")
        let root = try add(project: p); var chain = [root]
        for i in 2...10 { chain.append(try add("第\(i)层", parent: chain.last!.id)) }
        fails("depth_exceeded") { _ = try self.add(parent: chain.last!.id) }
        fails("cycle_detected") { try self.mutate("move", root.id, ["parent": chain[3].id]) }
        let branch = try add(project: p); let child = try add(parent: branch.id)
        fails("depth_exceeded") { try self.mutate("move", branch.id, ["parent": chain[8].id]) }
        XCTAssertNil(try task(branch.id).parentID)
        let qRoot = try add(project: q)
        fails("invalid_field") { _ = try self.add(parent: root.id, extra: ["project": q]) }
        fails("invalid_field") { try self.mutate("move", branch.id, ["project": p, "parent": qRoot.id]) }
        try mutate("move", branch.id, ["project": q, "parent": qRoot.id])
        XCTAssertEqual(try task(child.id).projectID, q)
        try mutate("move", branch.id, ["project": "unclassified", "parent": "root"])
        XCTAssertNil(try task(branch.id).projectID); XCTAssertNil(try task(child.id).projectID)
    }
    func testStatusCascadeRollbackAndAncestorReopening() throws {
        let root = try add(), child = try add(parent: root.id), leaf = try add(parent: child.id)
        let before = try store.snapshot()
        fails("cascade_required") { try self.mutate("complete", root.id) }
        XCTAssertEqual(try store.snapshot(), before)
        try mutate("complete", leaf.id); XCTAssertEqual(try task(child.id).status, "todo")
        try mutate("complete", root.id, ["cascade": "true"])
        XCTAssertTrue(try store.snapshot().tasks.allSatisfy { $0.status == "done" && $0.completedAt != nil })
        try mutate("update", leaf.id, ["status": "in_progress"])
        XCTAssertEqual(try task(root.id).status, "todo"); XCTAssertEqual(try task(child.id).status, "todo")
        try mutate("complete", root.id, ["cascade": "true"])
        _ = try add(parent: leaf.id); XCTAssertEqual(try task(root.id).status, "todo")
    }
    func testConflictsIdempotencyAndDifferentConnections() throws {
        let a = try add(extra: ["request-key": "retry"])
        let b = try add(extra: ["request-key": "retry"]); XCTAssertEqual(a.id, b.id)
        fails("idempotency_conflict") { _ = try self.add("不同内容", extra: ["request-key": "retry"]) }
        let other = try Store(directory: directory)
        _ = try other.execute("update", ["id": a.id, "expected-revision": "1", "description": "用户新内容"])
        fails("revision_conflict") { _ = try self.call("update", ["id": a.id, "expected-revision": "1", "status": "done"]) }
        XCTAssertEqual(try task(a.id).description, "用户新内容"); XCTAssertEqual(try task(a.id).status, "todo")
        let queue = DispatchQueue(label: "concurrency", attributes: .concurrent), group = DispatchGroup()
        for n in 0..<12 { group.enter(); queue.async { defer { group.leave() }; do { let writer = try Store(directory: self.directory); _ = try writer.execute("add", ["project": "unclassified", "title": "并发\(n)", "request-key": "\(n)"]) } catch { XCTFail("\(error)") } } }
        group.wait(); XCTAssertEqual(try store.snapshot().tasks.count, 13)
    }
    func testAttachmentsDeletionRestoreAndFailure() throws {
        let a = try add(), child = try add(parent: a.id)
        let source = directory.appendingPathComponent("sample.png")
        let data = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aRZ0AAAAASUVORK5CYII=")!
        try data.write(to: source)
        try mutate("attachment add", child.id, ["path": source.path])
        let attachment = try XCTUnwrap(store.snapshot().attachments.first)
        try FileManager.default.removeItem(at: source)
        XCTAssertEqual(try Data(contentsOf: store.attachmentURL(attachment)), data)
        let rev = try task(child.id).revision
        fails("attachment_failed") { try self.mutate("attachment add", child.id, ["path": source.path]) }
        XCTAssertEqual(try task(child.id).revision, rev); XCTAssertEqual(try store.snapshot().attachments.count, 1)
        try mutate("attachment delete", child.id, ["attachment": attachment.id]); XCTAssertTrue(try store.snapshot().attachments[0].deleted)
        try mutate("attachment restore", child.id, ["attachment": attachment.id]); XCTAssertFalse(try store.snapshot().attachments[0].deleted)
        try mutate("delete", a.id); XCTAssertTrue(try store.snapshot().liveTasks.isEmpty)
        fails("invalid_field") { try self.mutate("restore", child.id) }
        try mutate("restore", a.id); XCTAssertEqual(try store.snapshot().liveTasks.count, 2)
        XCTAssertEqual(try Data(contentsOf: store.attachmentURL(attachment)), data)
    }
    func testRestoreRespectsMovedParentsAndDoesNotRestoreEarlierDeletion() throws {
        let p = try project("p"), q = try project("q")
        let root = try add(project: p), child = try add(parent: root.id), leaf = try add(parent: child.id)
        try mutate("delete", child.id)
        try mutate("move", root.id, ["project": q, "parent": "root"])
        try mutate("restore", child.id)
        XCTAssertEqual(try task(child.id).projectID, q); XCTAssertEqual(try task(leaf.id).projectID, q)
        try mutate("delete", leaf.id); try mutate("delete", root.id); try mutate("restore", root.id)
        XCTAssertNotNil(try task(leaf.id).deletionID)
    }
    func testContextPrivacyPaginationAndUnmatchedWrite() throws {
        let p = try project("p")
        _ = try add("one", project: p, extra: ["description": "private"]); _ = try add("two", project: p)
        let result = try call("context", ["cwd": directory.appendingPathComponent("p").path, "limit": "1"])
        XCTAssertEqual(result["truncated"] as? Bool, true)
        let rows = result["tasks"] as! [[String: Any]]; XCTAssertNil(rows[0]["description"]); XCTAssertNil(rows[0]["attachments"])
        fails("project_unmatched") { _ = try self.call("add", ["title": "ambiguous"]) }
        XCTAssertEqual(try store.snapshot().tasks.count, 2)
    }
    func testWindowRecoveryAndFixedAnchorGeometry() {
        let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
        for right in [true, false] { for down in [true, false] {
            var g = FloatingGeometry(anchor: CGPoint(x: 700, y: 600), size: CGSize(width: 400, height: 320), growsRight: right, growsDown: down)
            let anchor = g.anchor; g.size = CGSize(width: 500, height: 350)
            XCTAssertEqual(g.anchor, anchor)
            XCTAssertEqual(right ? g.frame.minX : g.frame.maxX, anchor.x)
            XCTAssertEqual(down ? g.frame.maxY : g.frame.minY, anchor.y)
            g.anchor = CGPoint(x: 9000, y: -8000); g.fit(in: screen, chooseDirection: true)
            XCTAssertTrue(screen.contains(g.frame)); XCTAssertTrue(screen.contains(g.anchor))
        } }
    }
}
