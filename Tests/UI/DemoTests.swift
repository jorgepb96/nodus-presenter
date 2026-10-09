import XCTest
final class DemoTests: XCTestCase {
    func testDemoQROpensWithoutVideoOrVolumeInPresentationAndSettings() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--pair", "nodus-presenter://demo", "--reset-preferences", "-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        app.launch()
        XCTAssertTrue(app.buttons["tools"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["slideCounter"].label, "3 / 8")
        app.buttons["next"].tap()
        XCTAssertEqual(app.staticTexts["slideCounter"].label, "4 / 8")

        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(app.buttons["next"].isHittable)
            XCTAssertFalse(app.buttons["videoPlayback"].exists)
            XCTAssertFalse(app.buttons["videoVolume"].exists)
            app.buttons["tools"].tap()
            app.swipeUp()
            XCTAssertFalse(app.sliders["macVolumeSlider"].exists)
            XCTAssertFalse(app.sliders["videoVolumeSlider"].exists)
            XCTAssertFalse(app.buttons["Reproducir vídeo"].exists)
            XCTAssertFalse(app.buttons["Pausar vídeo"].exists)
            app.buttons["dismissTools"].tap()
            app.buttons["preview"].tap()
            app.buttons["next"].tap()
            XCTAssertEqual(app.staticTexts["slideCounter"].label, "5 / 8")
            app.buttons["preview"].tap()
            XCTAssertEqual(app.staticTexts["slideCounter"].label, "4 / 8")
            let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            shot.name = "Demo without video or volume controls - \(orientation.rawValue)"
            shot.lifetime = .keepAlways; add(shot)
        }
    }

    func testNextSlideEyeRespondsAcrossItsTouchArea() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--reset-preferences", "-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        app.launch()
        XCTAssertTrue(app.buttons["tools"].waitForExistence(timeout: 10))
        app.buttons["tools"].tap()
        app.switches["showNextSlide"].coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        app.buttons["dismissTools"].tap()

        func checkEyeTouchArea() {
            let preview = app.buttons["nextSlidePreview"]
            XCTAssertTrue(preview.isHittable)
            XCTAssertGreaterThanOrEqual(preview.frame.height, 44)
            for point in [CGVector(dx: -22, dy: 0), CGVector(dx: -40, dy: -18), CGVector(dx: -4, dy: 18)] {
                let bounds = preview.frame
                preview.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: bounds.width + point.dx, dy: bounds.height / 2 + point.dy)).tap()
                XCTAssertEqual(app.staticTexts["slideCounter"].label, "4 / 8", "The first tap anywhere in the eye target must work.")
                XCTAssertEqual(app.buttons["preview"].label, "Volver a la diapositiva en pantalla")
                app.buttons["preview"].tap()
                XCTAssertEqual(app.staticTexts["slideCounter"].label, "3 / 8", "Private reading must not advance the audience slide.")
            }
        }

        for split in [0.0, 0.5, 1.0] {
            app.buttons["tools"].tap()
            app.sliders["layoutSlider"].adjust(toNormalizedSliderPosition: split)
            app.buttons["dismissTools"].tap()
            checkEyeTouchArea()
        }
        for tool in ["draw", "zoom"] {
            app.buttons["tool-\(tool)"].tap()
            checkEyeTouchArea()
            app.buttons["tool-\(tool)"].tap()
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Next slide eye with generous touch area"; screenshot.lifetime = .keepAlways; add(screenshot)
    }

    func testToolsAndBlackScreenFromPrivateReading() {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--reset-preferences", "-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        app.launch()
        XCTAssertTrue(app.buttons["preview"].waitForExistence(timeout: 10))
        let book = app.buttons["preview"], blackout = app.buttons["blackScreen"]
        let overlay = app.descendants(matching: .any)["blackScreenOverlay"].firstMatch
        book.tap(); app.buttons["next"].tap()
        XCTAssertEqual(app.staticTexts["slideCounter"].label, "4 / 8")
        XCTAssertTrue(book.isSelected)
        for tool in ["pointer", "flashlight", "draw", "zoom"] {
            let button = app.buttons["tool-\(tool)"]
            XCTAssertTrue(button.isEnabled); button.tap()
            XCTAssertTrue(button.isSelected)
            XCTAssertEqual(app.staticTexts["slideCounter"].label, "4 / 8")
            XCTAssertTrue(book.isSelected, "A global tool must not silently leave private reading.")
            button.tap(); XCTAssertFalse(button.isSelected)
        }
        blackout.tap()
        XCTAssertEqual(blackout.value as? String, "Activada")
        XCTAssertEqual(app.staticTexts["slideCounter"].label, "4 / 8")
        XCTAssertTrue(book.isSelected); XCTAssertFalse(overlay.exists)
        app.buttons["next"].tap()
        XCTAssertEqual(app.staticTexts["slideCounter"].label, "5 / 8")
        app.buttons["slides"].tap(); app.buttons["slide-cell-7"].tap()
        XCTAssertEqual(app.staticTexts["slideCounter"].label, "7 / 8")
        book.tap()
        XCTAssertEqual(app.staticTexts["slideCounter"].label, "3 / 8", "All private navigation must leave the audience unchanged.")
        XCTAssertTrue(overlay.exists)
        blackout.tap(); XCTAssertFalse(overlay.exists)
        XCTAssertEqual(blackout.value as? String, "Desactivada")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Private navigation remains isolated after global tool and blackout controls"
        screenshot.lifetime = .keepAlways; add(screenshot)
    }

    func testSlideSplitStopsAtUsefulSize() {
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "--reset-preferences", "-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]
        app.launch()
        XCTAssertTrue(app.buttons["tools"].waitForExistence(timeout: 10))
        app.buttons["tools"].tap()
        app.sliders["layoutSlider"].adjust(toNormalizedSliderPosition: 0)
        app.sliders["layoutSlider"].adjust(toNormalizedSliderPosition: 1)
        let settingsShot = XCTAttachment(screenshot: app.screenshot()); settingsShot.name = "Slide split maximum in settings"; settingsShot.lifetime = .keepAlways; add(settingsShot)
        app.buttons["dismissTools"].tap()
        let slide = app.images["Diapositiva 3"]
        XCTAssertEqual(slide.frame.width, app.frame.width - 32, accuracy: 2)
        let notesTop = app.buttons["notesFontDecrease"].frame.minY
        let divider = app.otherElements["panelDivider"]
        XCTAssertTrue(divider.exists)
        divider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)))
        XCTAssertEqual(app.buttons["notesFontDecrease"].frame.minY, notesTop, accuracy: 2)
        XCTAssertEqual(slide.frame.width, app.frame.width - 32, accuracy: 2)
        app.buttons["tools"].tap()
        app.switches["showNextSlide"].coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        app.sliders["layoutSlider"].adjust(toNormalizedSliderPosition: 1)
        app.buttons["dismissTools"].tap()
        XCTAssertTrue(app.buttons["nextSlidePreview"].exists)
        XCTAssertEqual(slide.frame.width, app.frame.width - 32, accuracy: 2)
        XCTAssertEqual(app.buttons["notesFontDecrease"].frame.minY - notesTop, 58, accuracy: 2)
        // The final slide has no next preview: clamp the old, larger split immediately.
        app.buttons["slides"].tap(); app.buttons["slide-cell-8"].tap()
        XCTAssertFalse(app.buttons["nextSlidePreview"].exists)
        XCTAssertEqual(app.buttons["notesFontDecrease"].frame.minY, notesTop, accuracy: 2)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Slide split capped at full width"; screenshot.lifetime = .keepAlways; add(screenshot)
        // The divider still moves back up to make the slide smaller.
        app.otherElements["panelDivider"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)))
        XCTAssertLessThan(app.images["Diapositiva 8"].frame.width, app.frame.width - 40)
        XCUIDevice.shared.orientation = .landscapeLeft
        let visibleNotes = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: app.buttons["notesFontDecrease"])
        XCTAssertEqual(XCTWaiter.wait(for: [visibleNotes], timeout: 5), .completed)
        app.buttons["tools"].tap()
        XCTAssertTrue(app.sliders["layoutSlider"].exists)
        app.buttons["dismissTools"].tap()
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["notesFontDecrease"].isHittable)
        XCTAssertLessThanOrEqual(app.images["Diapositiva 8"].frame.width, app.frame.width - 32 + 2)
    }

    func testAdaptiveBrandAppearance() {
        let app = XCUIApplication(); app.launchArguments = ["--demo", "-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]; app.launch()
        XCTAssertTrue(app.buttons["tools"].waitForExistence(timeout: 10))
        app.buttons["tools"].tap()
        let appearance = app.segmentedControls["appearancePicker"]
        XCTAssertTrue(appearance.waitForExistence(timeout: 5))
        appearance.buttons["Claro"].tap()
        app.buttons["theme-docencia"].tap()
        app.buttons["dismissTools"].tap()
        XCTAssertEqual(app.buttons["connectionStatus"].value as? String, "Naranja, Claro")
        XCTAssertTrue(app.staticTexts["presenterNotes"].isHittable)
        let light = XCTAttachment(screenshot: app.screenshot()); light.name = "Adaptive logo light Orange"; light.lifetime = .keepAlways; add(light)
        app.buttons["tools"].tap()
        app.segmentedControls["appearancePicker"].buttons["Oscuro"].tap()
        app.buttons["theme-estudio"].tap()
        app.buttons["dismissTools"].tap()
        XCTAssertEqual(app.buttons["connectionStatus"].value as? String, "Verde azulado, Oscuro")
        XCTAssertEqual(app.staticTexts["slideCounter"].label, "3 / 8")
        let dark = XCTAttachment(screenshot: app.screenshot()); dark.name = "Adaptive logo dark Teal"; dark.lifetime = .keepAlways; add(dark)
        app.terminate(); app.launch()
        XCTAssertTrue(app.buttons["connectionStatus"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["connectionStatus"].value as? String, "Verde azulado, Oscuro")
    }

    func testDemoNavigationAndPrivatePreview() {
        let app = XCUIApplication(); app.launchArguments = ["--demo", "--reset-preferences", "-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]; app.launch()
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
        app.buttons["tools"].tap(); XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 5))
        app.switches["showNextSlide"].coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertEqual(app.switches["showNextSlide"].value as? String, "1")
        app.sliders["layoutSlider"].adjust(toNormalizedSliderPosition: 0.6)
        let savedLayout = app.sliders["layoutSlider"].value as? String
        app.buttons["theme-estudio"].tap(); XCTAssertTrue(app.buttons["theme-estudio"].isSelected)
        let settingsScreenshot = XCTAttachment(screenshot: app.screenshot()); settingsScreenshot.name = "Layout and color themes"; settingsScreenshot.lifetime = .keepAlways; add(settingsScreenshot)
        app.buttons["dismissTools"].tap()
        XCTAssertTrue(app.buttons["nextSlidePreview"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot()); screenshot.name = "Adjustable presenter on iPhone"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.terminate()
        app.launchArguments = ["--demo", "-AppleLanguages", "(es)", "-AppleLocale", "es_ES"]; app.launch()
        XCTAssertTrue(app.buttons["nextSlidePreview"].waitForExistence(timeout: 10))
        app.buttons["tools"].tap(); XCTAssertTrue(app.buttons["theme-estudio"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["theme-estudio"].isSelected)
        let slider = app.sliders["layoutSlider"]
        XCTAssertTrue(slider.exists)
        XCTAssertEqual(slider.value as? String, savedLayout)
    }
}
