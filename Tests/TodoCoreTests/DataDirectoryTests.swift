import XCTest
@testable import TodoCore

final class DataDirectoryTests: XCTestCase {
    func testDefaultSelectionAndOverrideDoNotTouchDisk() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        #if DEBUG
        let expected = "Next-One"
        #else
        let expected = "Next-One-Release"
        #endif
        XCTAssertEqual(Store.resolveDirectory(environment: [:], applicationSupport: root), root.appendingPathComponent(expected))
        let explicit = root.appendingPathComponent("Explicit Data")
        XCTAssertEqual(Store.resolveDirectory(environment: ["TODO_AI_HOME": explicit.path], applicationSupport: root), explicit)
        XCTAssertEqual(Store.resolveDirectory(environment: ["NEXT_ONE_HOME": explicit.path, "TODO_AI_HOME": "/old"], applicationSupport: root), explicit)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.path))
    }

    func testNewAliasPreservesLiveLegacyDataAndSettings() throws {
        let fm = FileManager.default, root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let old = root.appendingPathComponent("Todo-AI-Release"), new = root.appendingPathComponent("Next-One-Release")
        let legacy = try Store(directory: old)
        _ = try legacy.execute("add", ["title": "Before rename", "project": "unclassified"])
        try Data("ja".utf8).write(to: old.appendingPathComponent("language.json"))
        try Data("attachment".utf8).write(to: old.appendingPathComponent("attachments/fixture.txt"))
        try Store.prepareDefaultDirectory(new, legacy: old)
        try Store.prepareDefaultDirectory(new, legacy: old)
        let renamed = try Store(directory: new)
        XCTAssertEqual(renamed.directory, new)
        XCTAssertEqual(try renamed.snapshot().tasks.map(\.title), ["Before rename"])
        _ = try renamed.execute("add", ["title": "After rename", "project": "unclassified"])
        XCTAssertEqual(try legacy.snapshot().tasks.count, 2)
        XCTAssertEqual(try Data(contentsOf: new.appendingPathComponent("language.json")), Data("ja".utf8))
        XCTAssertEqual(try Data(contentsOf: new.appendingPathComponent("attachments/fixture.txt")), Data("attachment".utf8))
        XCTAssertEqual(new.resolvingSymlinksInPath(), old.resolvingSymlinksInPath())
    }

    func testExistingNewDirectoryAndBrokenLinksAreNotOverwritten() throws {
        let fm = FileManager.default, root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let old = root.appendingPathComponent("old"), new = root.appendingPathComponent("new")
        try fm.createDirectory(at: old, withIntermediateDirectories: true)
        try fm.createDirectory(at: new, withIntermediateDirectories: true)
        try Store.prepareDefaultDirectory(new, legacy: old)
        XCTAssertNotEqual(new.resolvingSymlinksInPath(), old.resolvingSymlinksInPath())
        let broken = root.appendingPathComponent("broken")
        try fm.createSymbolicLink(at: broken, withDestinationURL: root.appendingPathComponent("missing"))
        XCTAssertThrowsError(try Store.prepareDefaultDirectory(broken, legacy: old))
        XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: broken.path), root.appendingPathComponent("missing").path)
        let invalid = root.appendingPathComponent("file")
        try Data("keep".utf8).write(to: invalid)
        XCTAssertThrowsError(try Store.prepareDefaultDirectory(root.appendingPathComponent("unused"), legacy: invalid))
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
