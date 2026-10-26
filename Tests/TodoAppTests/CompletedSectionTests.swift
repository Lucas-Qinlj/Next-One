import XCTest
import TodoCore
@testable import TodoApp

final class CompletedSectionTests: XCTestCase {
    @MainActor func testRootPartitionKeepsCompletedChildWithPendingParent() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try Store(directory: directory)
        _ = try store.execute("project create", ["name": "Project"])
        let project = try XCTUnwrap(store.snapshot().projects.first)
        _ = try store.execute("add", ["project": project.id, "title": "Parent"])
        let parent = try XCTUnwrap(store.snapshot().liveTasks.first)
        _ = try store.execute("add", ["parent": parent.id, "title": "Completed child", "status": "done"])
        _ = try store.execute("add", ["project": project.id, "title": "Completed root", "status": "done"])
        _ = try store.execute("add", ["project": "unclassified", "title": "Free done", "status": "done"])
        let model = AppModel(store: store)
        let list = TaskListView(model: model)
        XCTAssertEqual(list.pendingRoots.map(\.id), [parent.id])
        XCTAssertEqual(Set(list.completedRoots.map(\.title)), ["Completed root", "Free done"])
        XCTAssertEqual(list.pendingBoardKeys, ["p:" + project.id])
        let child = try XCTUnwrap(model.state.children(parent.id).first)
        XCTAssertEqual(TaskGroupView(model: model, tasks: model.state.children(parent.id), depth: 1, groupID: parent.id).done.map(\.id), [child.id])
        let originalOrder = model.state.boardKeys
        _ = try store.execute("update", ["id": parent.id, "expected-revision": "1", "status": "done"])
        model.refresh()
        XCTAssertTrue(list.pendingRoots.isEmpty)
        XCTAssertTrue(list.pendingBoardKeys.isEmpty)
        XCTAssertEqual(list.completedRoots.count, 3)
        XCTAssertEqual(model.state.children(parent.id).map(\.id), [child.id])
        XCTAssertEqual(model.state.boardKeys, originalOrder)
        let revision = try XCTUnwrap(model.state.liveTasks.first { $0.id == parent.id }).revision
        _ = try store.execute("update", ["id": parent.id, "expected-revision": String(revision), "status": "todo"])
        model.refresh()
        XCTAssertEqual(list.pendingRoots.map(\.id), [parent.id])
        XCTAssertEqual(list.pendingBoardKeys, ["p:" + project.id])
        model.scope = project.id
        XCTAssertEqual(list.completedRoots.map(\.title), ["Completed root"])
        model.scope = "unclassified"
        XCTAssertEqual(list.completedRoots.map(\.title), ["Free done"])
        let upper = ProjectTaskGroup(model: model, projectID: project.id, name: project.name, tasks: [], colorIndex: 0)
        let lower = ProjectTaskGroup(model: model, projectID: project.id, name: project.name, tasks: [], colorIndex: 0, completedSection: true)
        model.collapsed.insert(lower.key)
        XCTAssertFalse(model.collapsed.contains(upper.key))
        XCTAssertNotEqual(upper.key, lower.key)
    }
}
