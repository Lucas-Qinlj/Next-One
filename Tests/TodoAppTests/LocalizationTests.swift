import XCTest
import TodoCore
@testable import TodoApp

final class LocalizationTests: XCTestCase {
    func testLanguageResolutionAndSafeInterpolation() {
        XCTAssertEqual(Localization.resolve("system", preferredLanguages: ["fr-FR", "ja-JP", "en"]), "ja")
        XCTAssertEqual(Localization.resolve("system", preferredLanguages: ["zh-Hant-TW"]), "zh-Hans")
        XCTAssertEqual(Localization.resolve("system", preferredLanguages: ["de"]), "en")
        XCTAssertEqual(Localization.resolve("en", preferredLanguages: ["zh-Hans"]), "en")
        XCTAssertEqual(Localization.resolve("system", preferredLanguages: ["ko-KR"]), "ko")
        let filename = "待办 %2$@ 100% 日本語.png"
        XCTAssertEqual(Localization.text("已移除：\(filename)", language: "en"), "Removed: " + filename)
        XCTAssertEqual(Localization.text("已移除：\(filename)", language: "ja"), "削除済み：" + filename)
        XCTAssertEqual(Localization.text("已移除：\(filename)", language: "ko"), "삭제됨: " + filename)
        XCTAssertEqual(Localization.text("背景不透明度 \(90)%", language: "en"), "Background opacity 90%")
    }

    func testTranslationCoverageAndPlaceholders() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let resources = root.appendingPathComponent("Sources/TodoCore/Resources")
        func table(_ language: String) throws -> [String: String] {
            let data = try Data(contentsOf: resources.appendingPathComponent(language + ".lproj/Localizable.strings"))
            return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
        }
        let chinese = try table("zh-Hans")
        let pattern = try NSRegularExpression(pattern: #"%\d+\$@"#)
        func parameters(_ text: String) -> [String] {
            pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { (text as NSString).substring(with: $0.range) }.sorted()
        }
        for language in Localization.languages {
            let translations = try table(language)
            XCTAssertEqual(Set(translations.keys), Set(chinese.keys))
            for (key, value) in translations {
                XCTAssertFalse(value.isEmpty, key)
                XCTAssertEqual(parameters(key), parameters(value), key)
                // Read the actual packaged Bundle.module resources, not just the source files.
                XCTAssertEqual(Localization.text(LocalizedText(stringLiteral: key), language: language), value, key)
            }
        }
    }

    @MainActor func testPersistenceIsolationDraftAndErrors() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try Store(directory: directory)
        _ = try store.execute("add", ["project": "unclassified", "title": "中文 English 日本語"])
        let model = AppModel(store: store)
        model.select(try XCTUnwrap(store.snapshot().liveTasks.first))
        model.draft?.description = "Unsaved draft"
        model.newTitle = "Quick add draft"
        let snapshot = try store.snapshot()
        for language in Localization.languages {
            try LanguageSettings.shared.select(language)
            XCTAssertEqual(model.draft?.description, "Unsaved draft")
            XCTAssertEqual(model.newTitle, "Quick add draft")
            XCTAssertEqual(try store.snapshot(), snapshot)
            let restored = LanguageSettings(); restored.load(directory: directory)
            XCTAssertEqual(restored.preference, language)
        }
        try LanguageSettings.shared.select("en")
        XCTAssertFalse(model.run("add", ["title": "", "project": "unclassified"]))
        XCTAssertEqual(model.toast?.message, "Missing title.")
        do { _ = try store.execute("add", ["title": "", "project": "unclassified"]); XCTFail() }
        catch let error as TodoError { XCTAssertEqual(error.message, "缺少 title。"); XCTAssertEqual(error.code, "invalid_field") }
        let isolated = LanguageSettings(); isolated.load(directory: directory.appendingPathComponent("another"))
        XCTAssertEqual(isolated.preference, "system")
        try LanguageSettings.shared.select("system")
    }

    @MainActor func testFailedPreferenceWriteKeepsSelection() throws {
        let settings = LanguageSettings()
        settings.load(directory: URL(fileURLWithPath: "/nonexistent-" + UUID().uuidString))
        XCTAssertThrowsError(try settings.select("ja"))
        XCTAssertEqual(settings.preference, "system")
    }

    func testTranslatedInstallPromptKeepsPathsAndRules() {
        let integration = CodexIntegration(skill: URL(fileURLWithPath: "/test 空間/%1$@/SKILL.md"), cli: URL(fileURLWithPath: "/test/bin/next-one"))
        for language in Localization.languages {
            let prompt = integration.installPrompt(dataDirectory: URL(fileURLWithPath: "/test/data"), language: language)
            XCTAssertFalse(prompt.contains("todo-ai"))
            XCTAssertFalse(prompt.contains("TODO_AI_HOME"))
            for value in [integration.skill.path, integration.cli.path, "/test/data", "~/.agents/skills/next-one", "NEXT_ONE_HOME", "revision", "project list", "context"] {
                XCTAssertTrue(prompt.contains(value), "\(language): \(value)")
            }
            if language == "en" { XCTAssertTrue(prompt.hasPrefix("Please install")) }
            if language == "ko" { XCTAssertTrue(prompt.hasPrefix("이 Mac")) }
            if language == "ja" { XCTAssertTrue(prompt.hasPrefix("この Mac")) }
        }
    }
}
