import XCTest
@testable import TodoCore

final class CodexSetupTests: XCTestCase {
    var root: URL!
    var data: URL { root.appendingPathComponent("Data ' with spaces") }
    var skills: URL { root.appendingPathComponent("skills") }
    var codex: URL { root.appendingPathComponent("codex") }
    var target: URL { skills.appendingPathComponent("todo-ai") }
    var setup: CodexSetup { CodexSetup(dataDirectory: data, skillsDirectory: skills, codexDirectory: codex) }
    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try version("v1")
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: root) }
    func write(_ text: String, _ url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }
    func read(_ url: URL) throws -> String { try String(contentsOf: url, encoding: .utf8) }
    func version(_ name: String) throws {
        let version = data.appendingPathComponent("integration/versions/" + name)
        try write("---\nname: todo-ai\ndescription: " + name + "\n---", version.appendingPathComponent("skills/todo-ai/SKILL.md"))
        try write("CLI", version.appendingPathComponent("skills/todo-ai/references/cli.md"))
        let cli = version.appendingPathComponent("bin/todo")
        try write("#!/bin/sh\nprintf '%s|" + name + "\\n' \"$TODO_AI_HOME\"\n", cli)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cli.path)
        let current = data.appendingPathComponent("integration/current")
        try? FileManager.default.removeItem(at: current)
        try FileManager.default.createSymbolicLink(at: current, withDestinationURL: version)
    }
    func run() throws -> String {
        let process = Process(); let pipe = Pipe()
        process.executableURL = target.appendingPathComponent("run"); process.standardOutput = pipe
        try process.run(); let bytes = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit()
        XCTAssertEqual(process.terminationStatus, 0)
        return String(decoding: bytes, as: UTF8.self)
    }
    func testInstallRepeatUpgradeAndUninstallPreserveCustomContent() throws {
        let rules = codex.appendingPathComponent("AGENTS.md"), original = "# Existing rules\n保留其他规则。\n"
        try write(original, rules)
        let result = try setup.execute("install")
        XCTAssertTrue(FileManager.default.fileExists(atPath: (result["backup_path"] as! String) + "/AGENTS.md"))
        XCTAssertTrue(try read(rules).hasPrefix(original))
        try write("My personal preferences", target.appendingPathComponent("USER.md"))
        let installed = try read(target.appendingPathComponent("SKILL.md"))
        let installedRules = try read(rules)
        XCTAssertEqual(try setup.execute("install")["changed"] as? Bool, false)
        XCTAssertEqual(try run(), data.path + "|v1\n")
        try version("v2")
        XCTAssertEqual(try run(), data.path + "|v2\n")
        XCTAssertEqual(try read(target.appendingPathComponent("SKILL.md")), installed)
        XCTAssertEqual(try read(rules), installedRules)
        XCTAssertTrue(try read(data.appendingPathComponent("integration/current/skills/todo-ai/SKILL.md")).contains("v2"))
        XCTAssertEqual(try setup.execute("status")["active_rules"] as? Bool, true)
        _ = try setup.execute("uninstall")
        XCTAssertEqual(try read(rules), original)
        XCTAssertEqual(try read(target.appendingPathComponent("USER.md")), "My personal preferences")
        XCTAssertFalse(FileManager.default.fileExists(atPath: data.appendingPathComponent("todo.sqlite").path))
        _ = try setup.execute("install")
        XCTAssertEqual(try read(target.appendingPathComponent("USER.md")), "My personal preferences")
        XCTAssertEqual(try setup.execute("status")["installed"] as? Bool, true)
    }
    func testEditedManagedFilesAndRulesAreNotOverwritten() throws {
        _ = try setup.execute("install")
        let file = target.appendingPathComponent("SKILL.md"), original = try read(file)
        try write(original + "User edits", file)
        XCTAssertThrowsError(try setup.execute("install"))
        XCTAssertThrowsError(try setup.execute("uninstall"))
        XCTAssertEqual(try read(file), original + "User edits")
        try write(original, file)
        let rules = codex.appendingPathComponent("AGENTS.md")
        let changed = try read(rules).replacingOccurrences(of: "Maintain", with: "Changed") + "outside\n"
        try write(changed.replacingOccurrences(of: "User instructions take precedence.", with: "My changed rule."), rules)
        let before = try read(rules)
        XCTAssertThrowsError(try setup.execute("install"))
        XCTAssertThrowsError(try setup.execute("uninstall"))
        XCTAssertEqual(try read(rules), before)
    }
    func testUnmanagedSkillAndDifferentBindingArePreserved() throws {
        try write("Legacy customization", target.appendingPathComponent("SKILL.md"))
        XCTAssertThrowsError(try setup.execute("install"))
        XCTAssertEqual(try read(target.appendingPathComponent("SKILL.md")), "Legacy customization")
        try FileManager.default.removeItem(at: target)
        _ = try setup.execute("install")
        let other = CodexSetup(dataDirectory: root.appendingPathComponent("Other"), skillsDirectory: skills, codexDirectory: codex)
        XCTAssertThrowsError(try other.execute("status"))
        XCTAssertThrowsError(try other.execute("uninstall"))
        XCTAssertEqual(try setup.execute("status")["installed"] as? Bool, true)
    }
    func testOverrideSelectionAndLaterOverrideChange() throws {
        let normal = codex.appendingPathComponent("AGENTS.md"), override = codex.appendingPathComponent("AGENTS.override.md")
        try write("Base content", normal); try write("Override content", override)
        XCTAssertEqual(try setup.execute("install")["rules_path"] as? String, override.path)
        XCTAssertEqual(try read(normal), "Base content")
        _ = try setup.execute("uninstall")
        try write("", override)
        XCTAssertEqual(try setup.execute("install")["rules_path"] as? String, normal.path)
        try write("New override", override)
        XCTAssertEqual(try setup.execute("status")["active_rules"] as? Bool, false)
        XCTAssertThrowsError(try setup.execute("install"))
        _ = try setup.execute("uninstall")
        XCTAssertEqual(try read(override), "New override")
    }
    func testStatusIsReadOnlyAndMissingResourcesFailBeforeConfiguration() throws {
        XCTAssertEqual(try setup.execute("status")["installed"] as? Bool, false)
        XCTAssertFalse(FileManager.default.fileExists(atPath: codex.path))
        try FileManager.default.removeItem(at: data.appendingPathComponent("integration/current/bin/todo"))
        XCTAssertThrowsError(try setup.execute("install"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: codex.path))
    }
    func testSymlinkAndUnownedRulesAreRejected() throws {
        let external = root.appendingPathComponent("external")
        try write("Do not touch", external)
        try FileManager.default.createDirectory(at: codex, withIntermediateDirectories: true)
        let rules = codex.appendingPathComponent("AGENTS.md")
        try FileManager.default.createSymbolicLink(at: rules, withDestinationURL: external)
        XCTAssertThrowsError(try setup.execute("install"))
        XCTAssertEqual(try read(external), "Do not touch")
        try FileManager.default.removeItem(at: rules)
        try write("<!-- TODO-AI:BEGIN -->unowned<!-- TODO-AI:END -->", rules)
        XCTAssertThrowsError(try setup.execute("install"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: target.path))
    }
}
