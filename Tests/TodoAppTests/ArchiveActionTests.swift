import XCTest
import TodoCore
@testable import TodoApp

final class ArchiveActionTests: XCTestCase {
    @MainActor func testCancelThenConfirmArchivesAsynchronously() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try Store(directory: directory)
        _ = try store.execute("add", ["project":"unclassified", "title":"Done", "status":"done"])
        let model = AppModel(store: store)
        model.archiveCompleted()
        XCTAssertNotNil(model.confirm)
        model.confirm = nil
        XCTAssertEqual(try store.snapshot().liveTasks.count, 1)
        model.archiveCompleted()
        let action = try XCTUnwrap(model.confirm?.action)
        model.confirm = nil
        action()
        XCTAssertTrue(model.isArchiving)
        let deadline = Date().addingTimeInterval(5)
        while model.isArchiving && Date() < deadline { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(model.isArchiving)
        XCTAssertTrue(model.state.liveTasks.isEmpty)
        XCTAssertEqual(model.state.nextTaskNumber, 1)
        XCTAssertNil(model.state.tasks.first?.shortCode)
    }
}
