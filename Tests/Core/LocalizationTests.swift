import XCTest
@testable import PresenterCore

final class LocalizationTests: XCTestCase {
    func testDeviceLanguageRegionsAndChineseScripts() {
        let cases: [([String], String)] = [
            ([], "en"), (["en-GB"], "en"), (["es-MX"], "es"), (["fr-CA"], "fr"),
            (["pt-BR"], "pt"), (["pt-PT"], "pt"), (["de_DE"], "de"), (["it-IT"], "it"), (["ja-JP"], "ja"),
            (["zh-TW"], "zh-Hant"), (["zh-HK"], "zh-Hant"), (["zh-MO"], "zh-Hant"),
            (["zh-CN"], "zh-Hans"), (["zh-SG"], "zh-Hans"), (["zh"], "zh-Hans"),
            (["zh-Hant-CN"], "zh-Hant"), (["zh-Hans-HK"], "zh-Hans"),
            (["ru-RU", "es-ES"], "en"), (["ar", "fr"], "en"), ([""], "en")
        ]
        for (preferences, expected) in cases {
            XCTAssertEqual(L10n.resolveLanguage(preferences), expected, "\(preferences)")
        }
    }

    func testEveryShippedLanguageHasCompleteNativeResourcesAndValidFormats() throws {
        func strings(_ language: String) throws -> [String: String] {
            let bundle = try XCTUnwrap(L10n.bundle(for: language), language)
            let url = try XCTUnwrap(bundle.url(forResource: "Localizable", withExtension: "strings"))
            let data = try Data(contentsOf: url)
            return try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String])
        }
        let english = try strings("en")
        XCTAssertGreaterThan(english.count, 100)
        let formats = try NSRegularExpression(pattern: #"%(?:\d+\$)?(?:\.\d+)?[@df]"#)
        func arguments(_ text: String) -> [String] {
            formats.matches(in: text, range: NSRange(text.startIndex..., in: text)).map {
                String(text[Range($0.range, in: text)!])
            }.sorted()
        }
        for language in L10n.supportedLanguages {
            let localized = try strings(language)
            XCTAssertEqual(Set(localized.keys), Set(english.keys), language)
            for (key, value) in localized {
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "\(language): \(key)")
                XCTAssertEqual(arguments(key), arguments(value), "\(language): \(key)")
            }
            let bundle = try XCTUnwrap(L10n.bundle(for: language), language)
            XCTAssertEqual(bundle.localizedString(forKey: "Next", value: nil, table: nil), localized["Next"])
        }
    }
}
