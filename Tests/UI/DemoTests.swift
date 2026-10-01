import XCTest
final class DemoTests: XCTestCase {
    func testDemoNavigationAndPrivatePreview() {
        let app = XCUIApplication(); app.launchArguments = ["--demo", "--reset-preferences"]; app.launch()
        XCTAssertTrue(app.staticTexts["slideCounter"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["slideCounter"].label, "3 / 8")
        app.buttons["next"].tap(); XCTAssertEqual(app.staticTexts["slideCounter"].label, "4 / 8")
        app.buttons["preview"].tap(); app.buttons["next"].tap()
        XCTAssertEqual(app.staticTexts["slideCounter"].label, "5 / 8")
        app.buttons["preview"].tap(); XCTAssertEqual(app.staticTexts["slideCounter"].label, "4 / 8")
        let current = app.images["Diapositiva 4"]
        current.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)).tap()
        XCTAssertEqual(app.staticTexts["slideCounter"].label, "5 / 8")
        app.images["Diapositiva 5"].coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5)).tap()
        XCTAssertEqual(app.staticTexts["slideCounter"].label, "4 / 8")
        for page in [2, 5, 3, 4] {
            app.buttons["slides"].tap()
            let tile = app.buttons["slide-cell-\(page)"]
            XCTAssertTrue(tile.waitForExistence(timeout: 5)); tile.tap()
            XCTAssertEqual(app.staticTexts["slideCounter"].label, "\(page) / 8")
        }
        XCTAssertTrue(app.buttons["connectionStatus"].label.contains("Demo"))
        XCTAssertTrue(app.staticTexts["presenterNotes"].isHittable)
        let increase = app.buttons["notesFontIncrease"], decrease = app.buttons["notesFontDecrease"]
        XCTAssertGreaterThanOrEqual(increase.frame.width, 44)
        XCTAssertGreaterThanOrEqual(increase.frame.minX - decrease.frame.maxX, 10)
        increase.tap(); XCTAssertEqual(app.staticTexts["presenterNotes"].value as? String, "Fuente 20")
        decrease.tap(); XCTAssertEqual(app.staticTexts["presenterNotes"].value as? String, "Fuente 18")
        app.buttons["zoomIn"].tap(); XCTAssertEqual(app.staticTexts["slideZoomValue"].label, "Zoom 125 por ciento")
        // Dragging an enlarged slide pans it; it must not advance the audience slide.
        let slide = app.images["Diapositiva 4"]
        slide.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)).press(forDuration: 0.1, thenDragTo: slide.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)))
        XCTAssertEqual(app.staticTexts["slideCounter"].label, "4 / 8")
        app.buttons["zoomOut"].tap(); XCTAssertEqual(app.staticTexts["slideZoomValue"].label, "Zoom 100 por ciento")
        app.buttons["blackScreen"].tap(); XCTAssertEqual(app.buttons["blackScreen"].value as? String, "Activada")
        app.buttons["blackScreen"].tap()
        app.buttons["tool-flashlight"].tap(); XCTAssertTrue(app.buttons["tool-flashlight"].isSelected)
        app.buttons["tool-flashlight"].tap()
        app.buttons["tool-draw"].tap()
        let sizeSlider = app.sliders["activeToolSize"]
        XCTAssertTrue(sizeSlider.waitForExistence(timeout: 5))
        sizeSlider.adjust(toNormalizedSliderPosition: 0.6)
        XCTAssertTrue(app.buttons["clearDraw"].exists)
        XCTAssertGreaterThan(sizeSlider.frame.minX, app.buttons["previous"].frame.maxX)
        XCTAssertLessThan(sizeSlider.frame.maxX, app.buttons["next"].frame.minX)
        app.images["Diapositiva 4"].coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)).tap()
        XCTAssertEqual(app.staticTexts["slideCounter"].label, "4 / 8")
        app.buttons["clearDraw"].tap()
        let drawingScreenshot = XCTAttachment(screenshot: app.screenshot()); drawingScreenshot.name = "Drawing controls between arrows"; drawingScreenshot.lifetime = .keepAlways; add(drawingScreenshot)
        app.buttons["tool-draw"].tap()
        app.buttons["tool-zoom"].tap()
        let magnifierSize = app.sliders["activeToolSize"], magnifierFactor = app.sliders["activeZoomFactor"]
        XCTAssertTrue(magnifierFactor.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(magnifierSize.frame.minX, app.buttons["previous"].frame.maxX)
        XCTAssertLessThan(magnifierFactor.frame.maxX, app.buttons["next"].frame.minX)
        XCTAssertGreaterThanOrEqual(magnifierSize.frame.minY, app.buttons["previous"].frame.minY - 2)
        XCTAssertLessThanOrEqual(magnifierFactor.frame.maxY, app.buttons["next"].frame.maxY + 2)
        let magnifierScreenshot = XCTAttachment(screenshot: app.screenshot()); magnifierScreenshot.name = "Magnifier controls between arrows"; magnifierScreenshot.lifetime = .keepAlways; add(magnifierScreenshot)
        app.buttons["tool-zoom"].tap()
        let timer = app.buttons["timer"]
        timer.tap(); XCTAssertTrue((timer.value as? String ?? "").contains("En marcha"))
        timer.tap(); XCTAssertTrue((timer.value as? String ?? "").contains("Pausado"))
        timer.press(forDuration: 0.8)
        XCTAssertEqual(timer.value as? String, "00:00, Pausado")
        XCTAssertFalse(app.buttons["nextSlidePreview"].exists)
        app.buttons["tools"].tap(); XCTAssertTrue(app.navigationBars["Herramientas"].waitForExistence(timeout: 5))
        app.switches["showNextSlide"].coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertEqual(app.switches["showNextSlide"].value as? String, "1")
        app.sliders["layoutSlider"].adjust(toNormalizedSliderPosition: 0.6)
        let savedLayout = app.sliders["layoutSlider"].value as? String
        app.buttons["theme-estudio"].tap(); XCTAssertTrue(app.buttons["theme-estudio"].isSelected)
        let settingsScreenshot = XCTAttachment(screenshot: app.screenshot()); settingsScreenshot.name = "Layout and vault themes"; settingsScreenshot.lifetime = .keepAlways; add(settingsScreenshot)
        app.buttons["Listo"].tap()
        XCTAssertTrue(app.buttons["nextSlidePreview"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Adjustable presenter on iPhone"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.terminate()
        app.launchArguments = ["--demo"]; app.launch()
        XCTAssertTrue(app.buttons["nextSlidePreview"].waitForExistence(timeout: 10))
        app.buttons["tools"].tap(); XCTAssertTrue(app.buttons["theme-estudio"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["theme-estudio"].isSelected)
        let slider = app.sliders["layoutSlider"]
        XCTAssertTrue(slider.exists)
        XCTAssertEqual(slider.value as? String, savedLayout)
    }
}
