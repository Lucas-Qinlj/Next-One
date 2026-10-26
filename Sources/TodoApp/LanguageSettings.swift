import AppKit
import Observation
import TodoCore

@MainActor @Observable final class LanguageSettings {
    static let shared = LanguageSettings()
    private(set) var preference = "system"
    private(set) var language = Localization.resolve("system")
    @ObservationIgnored private var file: URL?
    var locale: Locale { Locale(identifier: language) }

    func load(directory: URL) {
        file = directory.appendingPathComponent("language.json")
        preference = (try? JSONDecoder().decode(String.self, from: Data(contentsOf: file!))) ?? "system"
        if !(["system"] + Localization.languages).contains(preference) { preference = "system" }
        refreshSystemLanguage()
    }
    func select(_ value: String) throws {
        guard (["system"] + Localization.languages).contains(value), let file else { return }
        try JSONEncoder().encode(value).write(to: file, options: .atomic)
        preference = value
        refreshSystemLanguage()
    }
    func refreshSystemLanguage() {
        language = Localization.resolve(preference)
        NotificationCenter.default.post(name: .todoLanguageChanged, object: nil)
    }
    func date(_ value: String, dateOnly: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        let date = dateOnly ? formatter.date(from: value) : ISO8601DateFormatter().date(from: value)
        guard let date else { return value }
        formatter.locale = locale
        formatter.dateStyle = .medium
        formatter.timeStyle = dateOnly ? .none : .short
        return formatter.string(from: date)
    }
    func describe(_ error: Error) -> String {
        if let error = error as? TodoError { return Localization.text(error.localizedText, language: language) }
        if let error = error as? CodexIntegration.IntegrationError { return Localization.text(error.text, language: language) }
        return error.localizedDescription
    }
}
extension Notification.Name {
    static let todoLanguageChanged = Notification.Name("TodoAILanguageChanged")
}
@MainActor func L(_ text: LocalizedText) -> String {
    Localization.text(text, language: LanguageSettings.shared.language)
}
