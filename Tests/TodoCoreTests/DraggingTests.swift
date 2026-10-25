import XCTest
@testable import TodoCore

extension CoreTests {
    func testMixedBoardOrderAndProjectMovePreservesContents() throws {
        let p = try call("project create", ["name": "P"])["project"] as! [String: Any]
        let q = try call("project create", ["name": "Q"])["project"] as! [String: Any]
        let pid = p["id"] as! String, qid = q["id"] as! String
        let a = try add("A", project: pid), child = try add("Child", parent: a.id)
        _ = try add("B", project: qid)
        let free = try add("Free")
        let done = try add("Done", extra: ["status": "done"])
        let originalTasks = try store.snapshot().tasks
        _ = try call("board place", ["key": "p:" + qid, "expected-revision": "1", "expected-board-revision": "0", "anchor": "p:" + pid, "placement": "before"])
        XCTAssertEqual(try store.snapshot().boardKeys, ["p:" + qid, "p:" + pid, "t:" + free.id])
        XCTAssertEqual(try store.snapshot().tasks, originalTasks)
        _ = try call("board place", ["key": "t:" + a.id, "expected-revision": "1", "expected-board-revision": "1", "anchor": "p:" + pid, "placement": "before"])
        XCTAssertNil(try task(a.id).projectID)
        XCTAssertNil(try task(child.id).projectID)
        XCTAssertEqual(try task(child.id).parentID, a.id)
        XCTAssertEqual(try store.snapshot().boardKeys, ["p:" + qid, "t:" + a.id, "t:" + free.id])
        let reopened = try Store(directory: directory)
        XCTAssertEqual(try reopened.snapshot().boardKeys, try store.snapshot().boardKeys)
        fails("revision_conflict") { _ = try call("board place", ["key": "t:" + free.id, "expected-revision": "1", "expected-board-revision": "1", "placement": "end"]) }
        fails("invalid_field") { _ = try call("board place", ["key": "t:" + done.id, "expected-revision": "1", "expected-board-revision": "2", "placement": "end"]) }
        let before = try store.snapshot()
        fails("invalid_field") { _ = try call("board place", ["key": "t:" + free.id, "expected-revision": "1", "expected-board-revision": "2", "placement": "before", "anchor": "p:missing"]) }
        XCTAssertEqual(before, try store.snapshot())
    }
    func testPlaceOrderPersistenceAndBranchMove() throws {
        let a = try add("A"), b = try add("B"), c = try add("C")
        _ = try call("place", ["id": c.id, "expected-revision": "1", "anchor": a.id, "anchor-revision": "1", "placement": "before"])
        XCTAssertEqual(try store.snapshot().children(nil).map(\.id), [c.id, a.id, b.id])
        let again = try Store(directory: directory)
        XCTAssertEqual(try again.snapshot().children(nil).map(\.id), [c.id, a.id, b.id])
        let d = try add("New high", extra: ["priority": "high"])
        XCTAssertEqual(try store.snapshot().children(nil).last?.id, d.id)
        let child = try add("Child", parent: c.id)
        let p = try call("project create", ["name": "Later binding"])["project"] as! [String: Any]
        let pid = p["id"] as! String
        _ = try call("place", ["id": c.id, "expected-revision": String(try task(c.id).revision), "project": pid, "placement": "end", "parent": "root"])
        XCTAssertEqual(try task(c.id).projectID, pid)
        XCTAssertEqual(try task(child.id).projectID, pid)
        XCTAssertEqual(try task(child.id).parentID, c.id)
        _ = try call("place", ["id": c.id, "expected-revision": String(try task(c.id).revision), "project": "unclassified", "placement": "end", "parent": "root"])
        XCTAssertNil(try task(c.id).projectID)
        XCTAssertNil(try task(child.id).projectID)
    }
    func testGroupingNewAndEmptyProjectsAndLaterBinding() throws {
        let a = try add("A"), b = try add("B"), child = try add("Child", parent: a.id)
        let result = try call("group", ["id": a.id, "expected-revision": "1", "target": b.id, "target-revision": "1", "name": "New project"])
        let p = result["project"] as! [String: Any], pid = p["id"] as! String
        XCTAssertEqual((p["paths"] as! [String]).count, 0)
        XCTAssertEqual(try task(child.id).projectID, pid)
        XCTAssertEqual(try store.snapshot().children(nil).filter { $0.projectID == pid }.map(\.id), [b.id, a.id])
        _ = try call("project bind", ["project": pid, "expected-revision": "1", "path": directory.path])
        XCTAssertEqual(try store.snapshot().projects.first?.paths, [normalizedPath(directory.path)])
        let x = try add("X"), y = try add("Y")
        fails("invalid_field") { _ = try call("group", ["id": x.id, "expected-revision": "1", "target": y.id, "target-revision": "1", "project": pid]) }
        let empty = try call("project create", ["name": "Empty"])["project"] as! [String: Any]
        _ = try call("group", ["id": x.id, "expected-revision": "1", "target": y.id, "target-revision": "1", "project": empty["id"] as! String])
        XCTAssertEqual(try task(x.id).projectID, empty["id"] as? String)
    }
    func testDragConflictsCyclesAndGroupRollback() throws {
        let a = try add("A"), b = try add("B"), child = try add("Child", parent: a.id)
        let before = try store.snapshot()
        fails("cycle_detected") { _ = try call("place", ["id": a.id, "expected-revision": "1", "anchor": child.id, "anchor-revision": "1", "placement": "before"]) }
        fails("cycle_detected") { _ = try call("group", ["id": a.id, "expected-revision": "1", "target": child.id, "target-revision": "1", "name": "Must not exist"]) }
        fails("revision_conflict") { _ = try call("group", ["id": a.id, "expected-revision": "1", "target": b.id, "target-revision": "0", "name": "Must not exist"]) }
        fails("revision_conflict") { _ = try call("place", ["id": a.id, "expected-revision": "1", "anchor": b.id, "anchor-revision": "0", "placement": "before"]) }
        XCTAssertEqual(try store.snapshot(), before)
        _ = try call("group", ["id": a.id, "expected-revision": "1", "target": b.id, "target-revision": "1", "name": "Assigned"])
        let unclassified = try add("Free")
        fails("invalid_field") { _ = try call("group", ["id": a.id, "expected-revision": String(try task(a.id).revision), "target": unclassified.id, "target-revision": "1", "name": "Invalid"]) }
    }
    func testPlaceDepthAndStatusPartitionAndOldJSON() throws {
        let root = try add("Root")
        var bottom = root
        for n in 2...10 { bottom = try add("Level \(n)", parent: bottom.id) }
        let branch = try add("Branch"), child = try add("Branch child", parent: branch.id)
        let before = try store.snapshot()
        fails("depth_exceeded") { _ = try call("place", ["id": branch.id, "expected-revision": "1", "anchor": bottom.id, "anchor-revision": "1", "placement": "before"]) }
        XCTAssertEqual(try store.snapshot(), before)
        let done = try add("Done", extra: ["status": "done"])
        fails("invalid_field") { _ = try call("place", ["id": branch.id, "expected-revision": "1", "anchor": done.id, "anchor-revision": "1", "placement": "before"]) }
        let data = try JSONEncoder().encode(child)
        let legacy = try JSONDecoder().decode(TodoItem.self, from: data)
        XCTAssertNil(legacy.sortOrder)
    }
}
