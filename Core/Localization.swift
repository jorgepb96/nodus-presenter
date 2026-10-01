import Foundation

public enum L10n {
    public static let supportedLanguages = ["en", "es", "fr", "zh-Hans", "zh-Hant", "ja", "de", "it", "pt"]
    public static let language = resolveLanguage(Locale.preferredLanguages)
    public static let locale = Locale(identifier: language)
    private static let localizedBundle = bundle(for: language) ?? bundle(for: "en") ?? Bundle.module

    static func bundle(for language: String) -> Bundle? {
        guard supportedLanguages.contains(language), let root = Bundle.module.resourceURL else { return nil }
        // SwiftPM CLI lowercases script directories; Xcode preserves their casing.
        for name in [language, language.lowercased()] {
            if let bundle = Bundle(url: root.appendingPathComponent(name + ".lproj")) { return bundle }
        }
        return nil
    }

    /// Use the device's primary language. An unsupported primary language falls back to English.
    public static func resolveLanguage(_ preferences: [String]) -> String {
        guard let first = preferences.first else { return "en" }
        let parts = first.replacingOccurrences(of: "_", with: "-").lowercased().split(separator: "-").map(String.init)
        guard let language = parts.first else { return "en" }
        if language == "zh" {
            if parts.contains("hant") { return "zh-Hant" }
            if parts.contains("hans") { return "zh-Hans" }
            return parts.contains(where: { ["tw", "hk", "mo"].contains($0) }) ? "zh-Hant" : "zh-Hans"
        }
        return supportedLanguages.contains(language) ? language : "en"
    }

    public static func text(_ key: String, _ arguments: CVarArg...) -> String {
        let format = localizedBundle.localizedString(forKey: key, value: nil, table: nil)
        return arguments.isEmpty ? format : String(format: format, locale: locale, arguments: arguments)
    }
}
