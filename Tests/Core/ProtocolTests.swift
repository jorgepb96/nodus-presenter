import XCTest
@testable import PresenterCore

final class ProtocolTests: XCTestCase {
    func testPairingRejectsInvalidCredentialsAndDuplicateParameters() throws {
        let service = "nodus-12345678-1234-1234-1234-123456789abc"
        let key = Data(repeating: 7, count: 32).base64EncodedString()
        let good = URL(string: "nodus-presenter://pair?version=1&service=\(service)&key=\(key)&name=Mac")!
        XCTAssertEqual(try Pairing(url: good).key.count, 32)
        XCTAssertNil(try Pairing(url: good).lan, "Existing Mac QR keeps Bonjour/TLS-PSK")
        for suffix in ["&version=2", "&key=bad", "&service=../../file"] {
            XCTAssertThrowsError(try Pairing(url: URL(string: good.absoluteString + suffix)!))
        }
        XCTAssertThrowsError(try Pairing(url: URL(string: "https://example.com")!))
    }
    func testLANPairingRequiresPinnedCertificateAndBoundedIPv4Endpoints() throws {
        let key = Data(repeating: 8, count: 32).base64EncodedString()
        let url = "nodus-presenter://pair?version=2&transport=lan&service=nodus-12345678-1234-1234-1234-123456789abc&key=\(key)&fingerprint=\(String(repeating: "ab", count: 32))&hosts=192.168.1.10,10.0.0.2&port=43210&name=Linux"
        let pairing = try Pairing(url: URL(string: url)!)
        XCTAssertEqual(pairing.lan?.hosts, ["192.168.1.10", "10.0.0.2"])
        XCTAssertEqual(pairing.lan?.port, 43210)
        XCTAssertEqual(pairing.lan?.fingerprint, Data(repeating: 0xab, count: 32))
        XCTAssertEqual(pairing.name, "Linux")
        for (field, badValues) in [
            ("port", ["0", "65536", "-1", "https"]),
            ("hosts", ["example.com", "192.168.1.999", "0.0.0.0", "224.0.0.1", "192.168.01.2", "192.168.1.2,192.168.1.2", "192.168.1.2,"]),
            ("fingerprint", ["", "ab", String(repeating: "g", count: 64)]),
            ("transport", ["http", "bonjour", ""])
        ] {
            for value in badValues {
                var parts = URLComponents(string: url)!
                parts.queryItems = parts.queryItems!.map { $0.name == field ? URLQueryItem(name: field, value: value) : $0 }
                XCTAssertThrowsError(try Pairing(url: parts.url!), "\(field): \(value)")
            }
        }
        XCTAssertThrowsError(try Pairing(url: URL(string: url + "&port=1234")!))
        XCTAssertThrowsError(try Pairing(url: URL(string: url.replacingOccurrences(of: "version=2", with: "version=3"))!))
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
