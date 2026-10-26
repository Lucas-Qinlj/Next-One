import Foundation

/// Keep the template separate from values, so user content is never translated.
public struct LocalizedText: ExpressibleByStringLiteral, ExpressibleByStringInterpolation {
    public let key: String
    public let arguments: [String]
    public init(stringLiteral value: String) { key = value; arguments = [] }
    public init(stringInterpolation: StringInterpolation) {
        key = stringInterpolation.key; arguments = stringInterpolation.arguments
    }
    public struct StringInterpolation: StringInterpolationProtocol {
        var key = ""
        var arguments: [String] = []
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ literal: String) { key += literal }
        public mutating func appendInterpolation<T>(_ value: T) {
            arguments.append(String(describing: value)); key += "%\(arguments.count)$@"
        }
    }
    public var original: String { Localization.substitute(key, arguments) }
}

public enum Localization {
    public static let languages = ["zh-Hans", "en", "ja", "ko"]
    private static let bundles: [String: Bundle] = Dictionary(uniqueKeysWithValues: languages.compactMap { language in
        Bundle(url: Bundle.module.bundleURL.appendingPathComponent(language.lowercased() + ".lproj")).map { (language, $0) }
    })
    public static func resolve(_ preference: String, preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        if languages.contains(preference) { return preference }
        for language in preferredLanguages {
            switch language.lowercased().replacingOccurrences(of: "_", with: "-").split(separator: "-").first {
            case "zh": return "zh-Hans"
            case "en": return "en"
            case "ja": return "ja"
            case "ko": return "ko"
            default: continue
            }
        }
        return "en"
    }
    public static func text(_ text: LocalizedText, language: String) -> String {
        let bundle = bundles[language] ?? bundles["en"]
        let template = bundle?.localizedString(forKey: text.key, value: text.key, table: nil) ?? text.key
        return substitute(template, text.arguments)
    }
    private static let placeholder = try! NSRegularExpression(pattern: #"%(\d+)\$@"#)
    static func substitute(_ template: String, _ arguments: [String]) -> String {
        let result = NSMutableString(string: template)
        for match in placeholder.matches(in: template, range: NSRange(location: 0, length: result.length)).reversed() {
            let index = Int((template as NSString).substring(with: match.range(at: 1)))! - 1
            if arguments.indices.contains(index) { result.replaceCharacters(in: match.range, with: arguments[index]) }
        }
        return result as String
    }
}
