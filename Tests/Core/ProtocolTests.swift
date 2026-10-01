import XCTest
@testable import PresenterCore

final class ProtocolTests: XCTestCase {
    func testPairingRejectsInvalidCredentialsAndDuplicateParameters() throws {
        let service = "nodus-12345678-1234-1234-1234-123456789abc"
        let key = Data(repeating: 7, count: 32).base64EncodedString()
        let good = URL(string: "nodus-presenter://pair?version=1&service=\(service)&key=\(key)&name=Mac")!
        XCTAssertEqual(try Pairing(url: good).key.count, 32)
        for suffix in ["&version=2", "&key=bad", "&service=../../file"] {
            XCTAssertThrowsError(try Pairing(url: URL(string: good.absoluteString + suffix)!))
        }
        XCTAssertThrowsError(try Pairing(url: URL(string: "https://example.com")!))
    }
    func testFramesSurviveEveryPossibleTCPSplit() throws {
        let payload = Data("{\"kind\":\"state\",\"notes\":\"Conexión — 日本語\"}".utf8)
        let frame = try FrameDecoder.encode(payload)
        for split in 0...frame.count {
            var decoder = FrameDecoder()
            let first = try decoder.append(Data(frame.prefix(split)))
            let second = try decoder.append(Data(frame.dropFirst(split)))
            XCTAssertEqual(first + second, [payload])
        }
        var decoder = FrameDecoder()
        XCTAssertEqual(try decoder.append(frame + frame), [payload, payload])
    }
    func testOversizedAndEmptyFramesAreRejectedBeforeAllocation() {
        var decoder = FrameDecoder()
        XCTAssertThrowsError(try decoder.append(Data([0x7f, 0xff, 0xff, 0xff])))
        var empty = FrameDecoder()
        XCTAssertThrowsError(try empty.append(Data([0, 0, 0, 0])))
    }
    func testDemoReadAheadDoesNotAdvanceAudienceAndNavigationClamps() {
        var state = PresenterState(); state.totalSlides = 8
        state.applyDemo(["type": .string("navigate"), "slide": .number(999)])
        XCTAssertEqual(state.currentSlide, 8)
        state.applyDemo(["type": .string("next")]); XCTAssertEqual(state.currentSlide, 8)
        state.applyDemo(["type": .string("navigate"), "slide": .number(-5)])
        XCTAssertEqual(state.currentSlide, 1)
        state.applyDemo(["type": .string("setTool"), "tool": .string("flashlight")])
        XCTAssertEqual(state.toolMode, "flashlight")
        state.applyDemo(["type": .string("setTool"), "tool": .null]); XCTAssertNil(state.toolMode)
    }
}
