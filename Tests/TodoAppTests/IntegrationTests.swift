import XCTest
@testable import TodoApp

final class IntegrationTests: XCTestCase {
    private func fixture(_ root: URL) throws -> URL {
        let bundle = root.appendingPathComponent("移动前/Todo AI.app")
        let helper = bundle.appendingPathComponent("Contents/Helpers/next-one")
        let skill = bundle.appendingPathComponent("Contents/Resources/CodexIntegration/next-one")
        try FileManager.default.createDirectory(at: helper.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: skill.appendingPathComponent("references"), withIntermediateDirectories: true)
        try Data("#!/bin/sh\nprintf 'version-one'\n".utf8).write(to: helper)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper.path)
        try Data("---\nname: next-one\ndescription: Test fixture\n---".utf8).write(to: skill.appendingPathComponent("SKILL.md"))
        try Data("CLI reference".utf8).write(to: skill.appendingPathComponent("references/cli.md"))
        return bundle
    }
    func testPortablePathsMoveReuseUpdateAndRepair() throws {
        let fm = FileManager.default, root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let bundle = try fixture(root)
        let data = root.appendingPathComponent("Users/其他用户/Library/Application Support/Next-One")
        try fm.createDirectory(at: data, withIntermediateDirectories: true)
        let marker = data.appendingPathComponent("user-data.txt")
        try Data("untouched".utf8).write(to: marker)
        let first = try CodexIntegration.prepare(dataDirectory: data, bundleURL: bundle)
        XCTAssertTrue(first.cli.path.hasPrefix(data.path + "/integration/current/"))
        XCTAssertTrue(fm.isExecutableFile(atPath: first.cli.path))
        XCTAssertEqual(try String(contentsOf: first.skill.deletingLastPathComponent().appendingPathComponent("references/cli.md")), "CLI reference")
        let original = first.cli.resolvingSymlinksInPath()
        let moved = root.appendingPathComponent("Different Folder.app")
        try fm.moveItem(at: bundle, to: moved)
        let second = try CodexIntegration.prepare(dataDirectory: data, bundleURL: moved)
        XCTAssertEqual(second.cli.resolvingSymlinksInPath(), original)
        XCTAssertFalse(second.installPrompt(dataDirectory: data).contains(moved.path))
        let helper = moved.appendingPathComponent("Contents/Helpers/next-one")
        try Data("#!/bin/sh\nprintf 'version-two'\n".utf8).write(to: helper)
        let updated = try CodexIntegration.prepare(dataDirectory: data, bundleURL: moved)
        XCTAssertEqual(updated.cli, first.cli)
        XCTAssertNotEqual(updated.cli.resolvingSymlinksInPath(), original)
        XCTAssertTrue(fm.fileExists(atPath: original.path))
        try Data("corrupted".utf8).write(to: updated.cli.resolvingSymlinksInPath())
        let repaired = try CodexIntegration.prepare(dataDirectory: data, bundleURL: moved)
        XCTAssertTrue(try String(contentsOf: repaired.cli).contains("version-two"))
        let repeatRepair = try CodexIntegration.prepare(dataDirectory: data, bundleURL: moved)
        XCTAssertEqual(repaired.cli.resolvingSymlinksInPath(), repeatRepair.cli.resolvingSymlinksInPath())
        try fm.removeItem(at: helper)
        XCTAssertThrowsError(try CodexIntegration.prepare(dataDirectory: data, bundleURL: moved))
        XCTAssertTrue(try String(contentsOf: repaired.cli).contains("version-two"))
        XCTAssertEqual(try String(contentsOf: marker), "untouched")
    }
    func testDoesNotReplaceUserDirectoryAtCurrent() throws {
        let fm = FileManager.default, root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: root) }
        let bundle = try fixture(root), data = root.appendingPathComponent("data")
        let current = data.appendingPathComponent("integration/current")
        try fm.createDirectory(at: current, withIntermediateDirectories: true)
        let marker = current.appendingPathComponent("keep.txt")
        try Data("keep".utf8).write(to: marker)
        XCTAssertThrowsError(try CodexIntegration.prepare(dataDirectory: data, bundleURL: bundle))
        XCTAssertEqual(try String(contentsOf: marker), "keep")
    }
}
