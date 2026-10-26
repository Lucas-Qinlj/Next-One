import XCTest
@testable import TodoCore

final class DataDirectoryTests: XCTestCase {
    func testDefaultSelectionAndOverrideDoNotTouchDisk() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #if DEBUG
        let expected = "Todo-AI"
        #else
        let expected = "Todo-AI-Release"
        #endif
        XCTAssertEqual(Store.resolveDirectory(environment: [:], applicationSupport: root), root.appendingPathComponent(expected))
        let explicit = root.appendingPathComponent("Explicit Data")
        XCTAssertEqual(Store.resolveDirectory(environment: ["TODO_AI_HOME": explicit.path], applicationSupport: root), explicit)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    func testSeparateStoresPreserveExistingTasksAndSettings() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let legacy = root.appendingPathComponent("Todo-AI")
        let installed = root.appendingPathComponent("Todo-AI-Release")
        let dev = try Store(directory: legacy)
        _ = try dev.execute("add", ["title": "Development only", "project": "unclassified"])
        let settings = legacy.appendingPathComponent("language.json")
        try Data("\"ja\"".utf8).write(to: settings)
        let before = try Data(contentsOf: legacy.appendingPathComponent("todo.sqlite"))
        let release = try Store(directory: installed)
        XCTAssertTrue(try release.snapshot().tasks.isEmpty)
        _ = try release.execute("add", ["title": "Installed only", "project": "unclassified"])
        XCTAssertEqual(try dev.snapshot().tasks.map(\.title), ["Development only"])
        XCTAssertEqual(try Store(directory: installed).snapshot().tasks.map(\.title), ["Installed only"])
        XCTAssertEqual(try Data(contentsOf: legacy.appendingPathComponent("todo.sqlite")), before)
        XCTAssertEqual(try Data(contentsOf: settings), Data("\"ja\"".utf8))
        XCTAssertFalse(FileManager.default.fileExists(atPath: installed.appendingPathComponent("language.json").path))
    }
}
