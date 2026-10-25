import XCTest
import TodoCore
@testable import TodoApp

final class AutosaveTests: XCTestCase {
    @MainActor func testAutosaveAndConcurrentFields() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try Store(directory: directory)
        _ = try store.execute("add", ["project": "unclassified", "title": "Original"])
        let item = try XCTUnwrap(store.snapshot().liveTasks.first)
        let model = AppModel(store: store); model.select(item)
        model.draft?.description = "Local notes"; model.scheduleAutosave()
        _ = try store.execute("update", ["id": item.id, "expected-revision": "1", "priority": "high"])
        try await Task.sleep(for: .milliseconds(650))
        let saved = try XCTUnwrap(store.snapshot().liveTasks.first)
        XCTAssertEqual(saved.description, "Local notes")
        XCTAssertEqual(saved.priority, "high")
        XCTAssertFalse(model.dirty)
        XCTAssertNil(model.toast)
        model.draft?.description = "Local conflict"; model.scheduleAutosave()
        _ = try store.execute("update", ["id": item.id, "expected-revision": String(saved.revision), "description": "External"])
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertNotNil(model.confirm)
        XCTAssertEqual(model.draft?.description, "Local conflict")
        XCTAssertEqual(try store.snapshot().liveTasks.first?.description, "External")
        model.confirm?.action(); model.confirm = nil
        XCTAssertEqual(try store.snapshot().liveTasks.first?.description, "Local conflict")
    }
    @MainActor func testEmptyTitleAndNavigationFlush() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try Store(directory: directory)
        _ = try store.execute("add", ["project": "unclassified", "title": "Original"])
        let model = AppModel(store: store); model.select(try XCTUnwrap(store.snapshot().liveTasks.first))
        model.draft?.title = ""; model.scheduleAutosave()
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertTrue(model.dirty)
        XCTAssertEqual(try store.snapshot().liveTasks.first?.title, "Original")
        model.draft?.title = "Changed"; model.scheduleAutosave(); model.back()
        XCTAssertNil(model.selectedID)
        XCTAssertEqual(try store.snapshot().liveTasks.first?.title, "Changed")
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(try store.snapshot().liveTasks.first?.revision, 2)
    }
}
