import XCTest
import CSQLite
@testable import TodoCore

extension CoreTests {
    func testArchiveCompletedBranchesAndReuseThenRestore() throws {
        let parent = try add("Pending parent")
        let child = try add("Done child", parent: parent.id, extra: ["status":"done"])
        let other = try add("Done root", extra: ["status":"done"])
        let leaf = try add("Done leaf", parent: other.id, extra: ["status":"done"])
        let preview = try call("archive preview", [:])
        XCTAssertEqual(preview["count"] as? Int, 3)
        let args = ["expected-token":preview["token"] as! String, "request-key":"archive-once"]
        let result = try call("archive completed", args)
        XCTAssertEqual(result["count"] as? Int, 3)
        XCTAssertEqual(try task(parent.id), parent)
        XCTAssertEqual(try task(child.id).parentID, parent.id)
        XCTAssertNil(try task(child.id).shortCode)
        XCTAssertEqual(try task(other.id).deletionID, try task(leaf.id).deletionID)
        XCTAssertNotEqual(try task(child.id).deletionID, try task(other.id).deletionID)
        let created = try add("Reused code")
        XCTAssertEqual(created.shortCode, "A2") // A1 remains in use.
        let beforeRetry = try store.snapshot()
        _ = try call("archive completed", args)
        XCTAssertEqual(try store.snapshot(), beforeRetry)
        fails("invalid_field") { _ = try self.call("complete", ["id":"A2", "expected-revision":"1"]) }
        XCTAssertEqual(try task(created.id).status, "todo")
        try mutate("restore", child.id)
        XCTAssertEqual(try task(child.id).shortCode, "A3")
        XCTAssertEqual(try task(child.id).parentID, parent.id)
        XCTAssertEqual(try task(child.id).status, "done")
        try mutate("restore", other.id)
        XCTAssertEqual(Set([try task(other.id).shortCode!, try task(leaf.id).shortCode!]), ["A4","A5"])
        let live = try store.snapshot().liveTasks
        XCTAssertEqual(Set(live.compactMap(\.shortCode)).count, live.count)
    }
    func testArchiveConflictAndCancelLeaveStateUntouched() throws {
        let first = try add("Done", extra: ["status":"done"])
        let preview = try call("archive preview", [:])
        let beforePreview = try store.snapshot()
        _ = try call("archive preview", [:])
        XCTAssertEqual(try store.snapshot(), beforePreview)
        try mutate("update", first.id, ["status":"todo"])
        let changed = try store.snapshot()
        fails("revision_conflict") { _ = try self.call("archive completed", ["expected-token":preview["token"] as! String]) }
        XCTAssertEqual(try store.snapshot(), changed)
        let empty = try call("archive preview", [:])
        _ = try call("archive completed", ["expected-token":empty["token"] as! String])
        XCTAssertEqual(try add("Next").shortCode, "A2")
    }
}

final class ArchiveScaleTests: XCTestCase {
    func testFiftyThousandArchiveAndThresholdWithVersionTwoMigration() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var state = Snapshot()
        state.tasks = (1...50_000).map { n in
            TodoItem(id: "task-\(n)", shortCode: Snapshot.taskCode(n), title: "Synthetic \(n)", status: n == 1 ? "todo" : "done")
        }
        state.nextTaskNumber = 50_001
        XCTAssertTrue(state.needsCodeArchiving)
        var boundary = Snapshot()
        boundary.tasks = [TodoItem(shortCode: "ZZ9", title: "Three")]
        XCTAssertFalse(boundary.needsCodeArchiving)
        boundary.tasks[0].shortCode = "AAA1"
        XCTAssertTrue(boundary.needsCodeArchiving)
        boundary.tasks[0].deletionID = "trash"
        XCTAssertFalse(boundary.needsCodeArchiving)
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(directory.appendingPathComponent("todo.sqlite").path, &db), SQLITE_OK)
        let json = String(decoding: try JSONEncoder().encode(state), as: UTF8.self).replacingOccurrences(of: "'", with: "''")
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE state(id INTEGER PRIMARY KEY, json TEXT); INSERT INTO state VALUES(1,'\(json)'); PRAGMA user_version=2", nil,nil,nil), SQLITE_OK)
        sqlite3_close(db)
        let store = try Store(directory: directory)
        XCTAssertEqual(try store.snapshot().tasks.first, state.tasks.first)
        let start = Date()
        let preview = try store.execute("archive preview")
        let result = try store.execute("archive completed", ["expected-token":preview["token"] as! String])
        XCTAssertEqual(result["count"] as? Int, 49_999)
        let after = try store.snapshot()
        XCTAssertEqual(after.liveTasks.count, 1)
        XCTAssertFalse(after.needsCodeArchiving)
        XCTAssertTrue(after.tasks.filter { $0.deletionID != nil }.allSatisfy { $0.shortCode == nil })
        let added = try store.execute("add", ["project":"unclassified", "title":"New"])["task"] as! [String:Any]
        XCTAssertEqual(added["short_code"] as? String, "A2")
        print("50k archive preview+commit+read+create seconds: \(Date().timeIntervalSince(start))")
    }
}
