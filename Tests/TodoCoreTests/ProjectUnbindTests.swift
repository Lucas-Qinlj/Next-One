import XCTest
@testable import TodoCore

extension CoreTests {
    func testUnbindPreservesProjectTasksAndFilesAndChecksRevision() throws {
        let extra = directory.appendingPathComponent("extra")
        try FileManager.default.createDirectory(at: extra, withIntermediateDirectories: true)
        let marker = extra.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: marker)
        let p = try call("project bind", ["path": directory.path, "name": "Project"])["project"] as! [String: Any]
        let id = p["id"] as! String
        _ = try call("project bind", ["path": extra.path, "project": id, "expected-revision": "1"])
        let item = try add("Keep task", project: id)
        let result = try call("project unbind", ["id": id, "path": extra.path, "expected-revision": "2"])
        XCTAssertEqual((result["project"] as! [String: Any])["paths"] as? [String], [normalizedPath(directory.path)])
        XCTAssertEqual(try task(item.id), item)
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))
        fails("revision_conflict") { _ = try call("project unbind", ["id": id, "path": directory.path, "expected-revision": "2"]) }
        let before = try store.snapshot()
        fails("not_found") { _ = try call("project unbind", ["id": id, "path": extra.path, "expected-revision": "3"]) }
        XCTAssertEqual(try store.snapshot(), before)
        _ = try call("project unbind", ["id": id, "path": directory.path, "expected-revision": "3"])
        XCTAssertEqual(try store.snapshot().projects.first?.paths, [])
        XCTAssertEqual(try task(item.id).projectID, id)
        fails("project_unmatched") { _ = try call("context", ["cwd": directory.path]) }
        _ = try call("project bind", ["path": extra.path, "project": id, "expected-revision": "4"])
        XCTAssertEqual(try store.snapshot().projects.first?.paths, [normalizedPath(extra.path)])
    }
}
