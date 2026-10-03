import XCTest
import UIKit

final class WelcomeLayoutTests: XCTestCase {
    func testLandscapeWelcomeFitsAndActionsWorkAfterRotation() {
        let app = XCUIApplication()
        defer { XCUIDevice.shared.orientation = .portrait }
        for language in ["es", "en", "de", "fr"] {
            XCUIDevice.shared.orientation = .landscapeLeft
            app.launchArguments = ["--reset-preferences", "-AppleLanguages", "(\(language))", "-AppleLocale", language]
            app.launch()
            XCTAssertTrue(app.buttons["scanQR"].waitForExistence(timeout: 10), language)
            XCTAssertEqual(app.scrollViews.count, 0, "Landscape should fit without scrolling: \(language)")
            for identifier in ["scanQR", "demo", "pasteSession", "privacyPolicy"] {
                let control = app.descendants(matching: .any)[identifier].firstMatch
                XCTAssertTrue(control.isHittable, "\(language): \(identifier)")
                XCTAssertGreaterThanOrEqual(control.frame.height, 44, identifier)
                XCTAssertGreaterThanOrEqual(control.frame.minY, app.frame.minY, identifier)
                XCTAssertLessThanOrEqual(control.frame.maxY, app.frame.maxY, identifier)
            }
            let capture = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            capture.name = "Welcome-landscape-\(language)"
            capture.lifetime = .keepAlways; add(capture)

            XCUIDevice.shared.orientation = .portrait
            Thread.sleep(forTimeInterval: 1)
            XCTAssertTrue(app.buttons["scanQR"].waitForExistence(timeout: 5))
            XCUIDevice.shared.orientation = .landscapeRight
            // The legacy simulator can report the new AX frames before the
            // screen finishes rotating; don't inject a touch into the transition.
            Thread.sleep(forTimeInterval: 1)
            app.buttons["pasteSession"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            XCTAssertTrue(app.alerts.textFields.firstMatch.waitForExistence(timeout: 5))
            let cancel = ["es": "Cancelar", "en": "Cancel", "de": "Abbrechen", "fr": "Annuler"][language]!
            // Target the visible action centre: XCTest's scroll-to-visible
            // reports (-1, -1) for this native alert row on the iOS 18 simulator.
            app.alerts.buttons[cancel].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            app.buttons["demo"].tap()
            XCTAssertTrue(app.buttons["next"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }
}
