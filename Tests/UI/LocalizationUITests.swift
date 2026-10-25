import XCTest

final class LocalizationUITests: XCTestCase {
    func testGermanDemoLongTitles() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--reset-preferences", "-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        XCTAssertTrue(app.images["Folie 3"].waitForExistence(timeout: 10))
        for slide in 3...4 {
            XCTAssertEqual(app.staticTexts["slideCounter"].label, "\(slide) / 8")
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "German fitted demo title \(slide)"; screenshot.lifetime = .keepAlways; add(screenshot)
            if slide == 3 { app.buttons["next"].tap() }
        }
    }

    func testEveryLanguageAndUnsupportedLanguageFallback() {
        let cases: [(String, String, String, String, String, String, String)] = [
            ("en", "Settings", "Next", "Violet", "Knowledge networks", "Knowledge networks let us connect people, ideas and opportunities in meaningful ways.", "You run the show."),
            ("es", "Ajustes", "Siguiente", "Violeta", "Redes de conocimiento", "Las redes de conocimiento nos permiten conectar personas, ideas y oportunidades de forma significativa.", "Tú tienes el mando."),
            ("fr", "Réglages", "Suivante", "Violet", "Réseaux de connaissances", "Les réseaux de connaissances nous permettent de relier les personnes, les idées et les opportunités de manière significative.", "Vous avez la main."),
            ("zh-Hans", "设置", "下一张", "紫罗兰", "知识网络", "知识网络让我们能够有意义地连接人、思想和机遇。", "全场由你掌控。"),
            ("zh-Hant", "設定", "下一張", "紫羅蘭", "知識網絡", "知識網絡讓我們能夠有意義地連結人、思想和機遇。", "全場由你掌控。"),
            ("ja", "設定", "次へ", "バイオレット", "知識のネットワーク", "知識のネットワークは、人、アイデア、機会を意味のある形で結びつけます。", "主導権は、あなたの手に。"),
            ("de", "Einstellungen", "Weiter", "Violett", "Wissensnetzwerke", "Wissensnetzwerke ermöglichen es uns, Menschen, Ideen und Chancen sinnvoll miteinander zu verbinden.", "Du hast das Sagen."),
            ("it", "Impostazioni", "Successiva", "Viola", "Reti di conoscenza", "Le reti di conoscenza ci permettono di collegare persone, idee e opportunità in modo significativo.", "Il comando è tuo."),
            ("pt", "Definições", "Seguinte", "Violeta", "Redes de conhecimento", "As redes de conhecimento permitem-nos ligar pessoas, ideias e oportunidades de forma significativa.", "O comando é teu."),
            ("ru", "Settings", "Next", "Violet", "Knowledge networks", "Knowledge networks let us connect people, ideas and opportunities in meaningful ways.", "You run the show.")
        ]
        let app = XCUIApplication()
        for (language, settings, next, violet, title, notes, welcome) in cases {
            app.launchArguments = ["--reset-preferences", "-AppleLanguages", "(\(language))", "-AppleLocale", language]
            app.launch()
            XCTAssertTrue(app.buttons["demo"].waitForExistence(timeout: 10), language)
            XCTAssertTrue(app.staticTexts[welcome].exists, language)
            app.buttons["demo"].tap()
            XCTAssertTrue(app.buttons["tools"].waitForExistence(timeout: 5), language)
            XCTAssertTrue(app.staticTexts[title].exists, language)
            XCTAssertTrue(app.staticTexts["presenterNotes"].label.hasPrefix(notes), language)
            XCTAssertEqual(app.buttons["next"].label, next, language)
            app.buttons["next"].tap()
            XCTAssertEqual(app.staticTexts["slideCounter"].label, "4 / 8", language)
            app.buttons["previous"].tap()
            let main = XCTAttachment(screenshot: app.screenshot())
            main.name = "Localized presenter \(language)"; main.lifetime = .keepAlways; add(main)
            app.buttons["tools"].tap()
            XCTAssertTrue(app.navigationBars[settings].waitForExistence(timeout: 5), language)
            XCTAssertEqual(app.buttons["theme-original"].label, violet, language)
            XCTAssertFalse(app.buttons["theme-primarySources"].exists, language)
            XCTAssertTrue(app.buttons["theme-worldbuilding"].isHittable, language)
            let themes = XCTAttachment(screenshot: app.screenshot())
            themes.name = "Localized color themes \(language)"; themes.lifetime = .keepAlways; add(themes)
            app.buttons["dismissTools"].tap()
            app.terminate()
        }
    }
}
