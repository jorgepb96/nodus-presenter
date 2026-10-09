import XCTest

/// Native, reproducible App Store captures; run explicitly with -only-testing.
final class StoreScreenshotTests: XCTestCase {
    func testEnglishStoreScreenshots() {
        XCUIDevice.shared.orientation = UIDevice.current.userInterfaceIdiom == .pad ? .landscapeLeft : .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        let english = ["--reset-preferences", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        func capture(_ name: String) {
            // Capture the display rather than the application bounds, which
            // XCTest can report in portrait coordinates after an iPad rotation.
            let image = XCUIScreen.main.screenshot().image
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1; format.opaque = true
            let pixels = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
            let png = UIGraphicsImageRenderer(size: pixels, format: format).pngData { _ in
                image.draw(in: CGRect(origin: .zero, size: pixels))
            }
            let shot = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
            shot.name = "AppStore-\(name)"; shot.lifetime = .keepAlways; add(shot)
        }
        app.launchArguments = english + ["--demo"]
        app.launch()
        XCTAssertTrue(app.buttons["tools"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["next"].label, "Next")
        app.buttons["tools"].tap()
        app.segmentedControls["appearancePicker"].buttons["Light"].tap()
        app.buttons["dismissTools"].tap()
        capture("01-presenter-notes")

        app.buttons["tools"].tap()
        app.segmentedControls["appearancePicker"].buttons["Dark"].tap()
        app.buttons["theme-estudio"].tap()
        app.switches["showNextSlide"].coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        app.buttons["dismissTools"].tap()
        app.buttons["tool-draw"].tap()
        XCTAssertTrue(app.buttons["clearDraw"].isHittable)
        capture("02-drawing-and-next-slide")
        app.buttons["tool-draw"].tap()

        app.buttons["next"].tap()
        XCTAssertFalse(app.buttons["videoPlayback"].exists)
        XCTAssertFalse(app.buttons["videoVolume"].exists)
        app.buttons["preview"].tap()
        app.buttons["next"].tap()
        capture("03-private-reading")
        app.buttons["preview"].tap()
        app.buttons["tool-flashlight"].tap()
        capture("04-spotlight")

        app.terminate()
        app.launchArguments = english + ["--demo", "--tools"]
        app.launch()
        XCTAssertTrue(app.buttons["theme-original"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.sliders["layoutSlider"].isHittable)
        capture("05-layout-and-colors")
        app.buttons["dismissTools"].tap()
        app.buttons["slides"].tap()
        XCTAssertTrue(app.buttons["slide-cell-1"].waitForExistence(timeout: 5))
        capture("06-slide-grid")

        app.terminate()
        app.launchArguments = english
        app.launch()
        XCTAssertTrue(app.buttons["scanQR"].waitForExistence(timeout: 10))
        capture("07-qr-connection")
    }
}
