import XCTest
import CSQLite
@testable import TodoCore

final class ShortCodeTests: XCTestCase {
    func testSequenceBoundariesAndUniqueness() {
        for (n, code) in [(1,"A1"),(9,"A9"),(10,"B1"),(234,"Z9"),(235,"AA1"),(243,"AA9"),(244,"AB1"),(6318,"ZZ9"),(6319,"AAA1")] {
            XCTAssertEqual(Snapshot.taskCode(n), code)
        }
        XCTAssertEqual(Set((1...10000).map(Snapshot.taskCode)).count, 10000)
    }
    func testLegacyMigrationKeepsAllTasksAndRevisions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var legacy = Snapshot()
        legacy.tasks = [TodoItem(id: "b", title: "Deleted", createdAt: "2020", revision: 5, deletionID: "deleted"), TodoItem(id: "a", title: "First", createdAt: "2020")]
        let json = String(decoding: try JSONEncoder().encode(legacy), as: UTF8.self).replacingOccurrences(of: "'", with: "''")
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(directory.appendingPathComponent("todo.sqlite").path, &db), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "CREATE TABLE state(id INTEGER PRIMARY KEY, json TEXT); INSERT INTO state VALUES(1,'\(json)'); PRAGMA user_version=1", nil, nil, nil), SQLITE_OK)
        sqlite3_close(db)
        let store = try Store(directory: directory)
        let state = try store.snapshot()
        XCTAssertEqual(state.tasks.map(\.shortCode), ["A2", "A1"])
        XCTAssertEqual(state.tasks.map(\.revision), [5, 1])
        XCTAssertEqual(state.tasks.map(\.deletionID), ["deleted", nil])
        XCTAssertEqual(state.tasks.map(\.createdAt), ["2020", "2020"])
        XCTAssertEqual(try Store(directory: directory).snapshot(), state)
        let new = try store.execute("add", ["project": "unclassified", "title": "New"])["task"] as! [String: Any]
        XCTAssertEqual(new["short_code"] as? String, "A3")
    }
}
extension CoreTests {
    func testShortCodeReferencesStayStableAndPreserveGuards() throws {
        let root = try add("Root", extra: ["request-key":"same"])
        XCTAssertEqual(root.shortCode, "A1")
        XCTAssertEqual(try add("Root", extra: ["request-key":"same"]).shortCode, "A1")
        let childJSON = try call("add", ["parent":"a1", "title":"Child"])["task"] as! [String:Any]
        XCTAssertEqual(childJSON["short_code"] as? String, "A2")
        let child = try task(childJSON["id"] as! String)
        fails("cascade_required") { _ = try self.call("complete", ["id":"A1", "expected-revision":"1"]) }
        fails("cycle_detected") { _ = try self.call("move", ["id":"A1", "parent":"a2", "expected-revision":"1"]) }
        XCTAssertEqual(try store.snapshot().tasks.count, 2)
        let projectID = try project("codes")
        _ = try call("move", ["id":"a1", "project":projectID, "expected-revision":"1", "parent":"root"])
        XCTAssertEqual(try task(child.id).shortCode, "A2")
        XCTAssertEqual(try task(child.id).projectID, projectID)
        let context = try call("context", ["cwd": directory.appendingPathComponent("codes").path])["tasks"] as! [[String:Any]]
        XCTAssertEqual(Set(context.compactMap { $0["short_code"] as? String }), ["A1","A2"])
        try mutate("delete", root.id)
        fails("not_found") { _ = try self.call("get", ["id":"A1"]) }
        let next = try add("No reuse")
        XCTAssertEqual(next.shortCode, "A3")
        _ = try call("restore", ["id":"a1", "expected-revision":String(try task(root.id).revision)])
        XCTAssertEqual(try task(root.id).shortCode, "A1")
        XCTAssertEqual(try task(child.id).shortCode, "A2")
        fails("not_found") { _ = try self.call("get", ["id":"A"]) }
        fails("invalid_field") { _ = try self.call("update", ["id":"A1", "expected-revision":String(try self.task(root.id).revision), "short-code":"Z9"]) }
        let codes = try store.snapshot().tasks.compactMap(\.shortCode)
        XCTAssertEqual(Set(codes).count, 3)
    }
    func testConcurrentShortCodesAreGlobalAndUnique() throws {
        let queue = DispatchQueue(label: "codes", attributes: .concurrent), group = DispatchGroup()
        for n in 0..<20 {
            group.enter(); queue.async {
                defer { group.leave() }
                do {
                    let writer = try Store(directory: self.directory)
                    _ = try writer.execute("add", ["project":"unclassified", "title":"Concurrent \(n)"])
                } catch { XCTFail("\(error)") }
            }
        }
        group.wait()
        let codes = try store.snapshot().tasks.compactMap(\.shortCode)
        XCTAssertEqual(codes.count, 20)
        XCTAssertEqual(Set(codes), Set((1...20).map(Snapshot.taskCode)))
    }
}

extension CoreTests {
    func testShortCodeOrderingAndDepthValidation() throws {
        let first = try add("First"), second = try add("Second")
        fails("invalid_field") { _ = try self.call("place", ["id":"A1", "anchor":first.id, "placement":"before", "expected-revision":"1", "anchor-revision":"1"]) }
        _ = try call("place", ["id":"A2", "anchor":"a1", "placement":"before", "expected-revision":"1", "anchor-revision":"1"])
        XCTAssertEqual(try store.snapshot().children(nil).first?.id, second.id)
        var parent = first
        for level in 2...10 {
            let value = try call("add", ["parent":parent.shortCode!, "title":"Level \(level)"])["task"] as! [String:Any]
            parent = try task(value["id"] as! String)
        }
        fails("depth_exceeded") { _ = try self.call("add", ["parent":parent.shortCode!, "title":"Too deep"]) }
        let after = try add("After failure")
        XCTAssertEqual(after.shortCode, Snapshot.taskCode(12))
    }
}
