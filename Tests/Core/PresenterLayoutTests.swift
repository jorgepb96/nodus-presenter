import XCTest
@testable import PresenterCore

final class PresenterLayoutTests: XCTestCase {
    func testPortraitStopsWhenSlideFillsWidth() {
        let width = 440.0, height = 740.0, aspect = 16.0 / 9
        let range = PresenterLayout.shareRange(width: width, height: height, aspectRatio: aspect, hasNext: false)
        let canvasHeight = (height - 24) * range.upperBound - PresenterLayout.chromeHeight(hasNext: false)
        XCTAssertEqual(canvasHeight * aspect, width - 32, accuracy: 0.001)
        XCTAssertLessThan(range.upperBound, 0.72)
        XCTAssertEqual(PresenterLayout.clamp(0.99, to: range), range.upperBound)
    }
    func testNextPreviewAddsOnlyItsOwnSpace() {
        let hidden = PresenterLayout.shareRange(width: 440, height: 740, aspectRatio: 16 / 9, hasNext: false)
        let visible = PresenterLayout.shareRange(width: 440, height: 740, aspectRatio: 16 / 9, hasNext: true)
        XCTAssertEqual((visible.upperBound - hidden.upperBound) * (740 - 24), 58, accuracy: 0.001)
        XCTAssertEqual(PresenterLayout.clamp(visible.upperBound, to: hidden), hidden.upperBound)
    }
    func testDifferentPageAspectAndWindowSizeChangeLimit() {
        let landscapePage = PresenterLayout.shareRange(width: 440, height: 740, aspectRatio: 16 / 9, hasNext: false)
        let portraitPage = PresenterLayout.shareRange(width: 440, height: 740, aspectRatio: 3 / 4, hasNext: false)
        let tallerWindow = PresenterLayout.shareRange(width: 440, height: 900, aspectRatio: 16 / 9, hasNext: false)
        XCTAssertGreaterThan(portraitPage.upperBound, landscapePage.upperBound)
        XCTAssertLessThan(tallerWindow.upperBound, landscapePage.upperBound)
    }
    func testWideLayoutStopsAtFullHeightAndLeavesRoomForNotes() {
        let range = PresenterLayout.shareRange(width: 1200, height: 400, aspectRatio: 16 / 9, hasNext: false)
        let slideWidth = (1200 - 52) * range.upperBound
        XCTAssertEqual(slideWidth / (16 / 9), 400 - 94, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual((1200 - 52) - slideWidth, 220)
        let short = PresenterLayout.shareRange(width: 740, height: 180, aspectRatio: 16 / 9, hasNext: false)
        XCTAssertEqual(short.lowerBound, short.upperBound)
    }
    func testInvalidGeometryAndNonFinitePreferenceRemainSafe() {
        XCTAssertEqual(PresenterLayout.shareRange(width: 0, height: 0, aspectRatio: 0, hasNext: false), PresenterLayout.defaultRange)
        let range = PresenterLayout.shareRange(width: 440, height: 3000, aspectRatio: 4, hasNext: false)
        XCTAssertGreaterThan(range.upperBound, range.lowerBound)
        XCTAssertEqual(PresenterLayout.clamp(.nan, to: range), range.lowerBound)
    }
}
