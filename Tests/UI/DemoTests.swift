import XCTest
final class DemoTests: XCTestCase {
    func testDemoNavigationAndPrivatePreview() {
        let app = XCUIApplication(); app.launchArguments = ["--demo"]; app.launch()
        XCTAssertTrue(app.staticTexts["slideCounter"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["slideCounter"].label, "3 / 8")
        app.buttons["next"].tap(); XCTAssertEqual(app.staticTexts["slideCounter"].label, "4 / 8")
        app.buttons["preview"].tap(); app.buttons["next"].tap()
        XCTAssertEqual(app.staticTexts["slideCounter"].label, "5 / 8")
        app.buttons["preview"].tap(); XCTAssertEqual(app.staticTexts["slideCounter"].label, "4 / 8")
        XCTAssertTrue(app.staticTexts["connectionStatus"].label.contains("Demo"))
        app.buttons["blackScreen"].tap(); XCTAssertEqual(app.buttons["blackScreen"].value as? String, "Activada")
        app.buttons["blackScreen"].tap()
        app.buttons["tool-flashlight"].tap(); XCTAssertTrue(app.buttons["tool-flashlight"].isSelected)
        app.buttons["tool-flashlight"].tap()
        app.buttons["tools"].tap(); XCTAssertTrue(app.navigationBars["Herramientas"].waitForExistence(timeout: 5))
    }
}
