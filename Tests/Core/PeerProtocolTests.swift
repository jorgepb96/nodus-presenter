import XCTest
@testable import PresenterCore

final class PeerProtocolTests: XCTestCase {
    private let key = Data(repeating: 7, count: 32)
    private let service = "nodus-12345678-1234-1234-1234-123456789abc"
    private func codecs(nonce: String = "connection-1") throws -> (PeerMessageCodec, PeerMessageCodec) {
        (try PeerMessageCodec(key: key, service: service, nonce: nonce, direction: .toMac),
         try PeerMessageCodec(key: key, service: service, nonce: nonce, direction: .toPhone))
    }
    func testAuthenticatedControlAndLargeAssetsRoundTripInBothDirections() throws {
        let (phone, mac) = try codecs()
        let action: Message = ["kind": .string("action"), "action": .object(["type": .string("setToolColor"), "color": .string("#abcdef")])]
        let control = try phone.seal(action, channel: .control)
        XCTAssertEqual(try mac.open(control.data).message, action)
        let asset: Message = ["kind": .string("image"), "data": .string(String(repeating: "ab", count: 400_000))]
        let image = try mac.seal(asset, channel: .assets)
        let decoded = try phone.open(image.data)
        XCTAssertEqual(decoded.message, asset)
        XCTAssertEqual(decoded.channel, .assets)
        XCTAssertEqual(decoded.sequence, 1)
        let ack = try phone.seal(["sequence": .number(1)], channel: .assetAcknowledgement)
        XCTAssertEqual(try mac.open(ack.data).channel, .assetAcknowledgement)
    }
    func testReplayOutOfOrderAndPreviousConnectionPacketsAreRejected() throws {
        let (phone, mac) = try codecs()
        let first = try phone.seal(["kind": .string("ping")], channel: .control)
        let second = try phone.seal(["kind": .string("ping")], channel: .control)
        XCTAssertThrowsError(try mac.open(second.data))
        XCTAssertEqual(try mac.open(first.data).sequence, 1)
        XCTAssertThrowsError(try mac.open(first.data))
        XCTAssertEqual(try mac.open(second.data).sequence, 2)
        let (_, freshMac) = try codecs(nonce: "connection-2")
        XCTAssertThrowsError(try freshMac.open(first.data))
    }
    func testSecretDirectionSessionAndHeaderAreAuthenticated() throws {
        let (phone, mac) = try codecs()
        let sealed = try phone.seal(["kind": .string("hello")], channel: .control)
        XCTAssertThrowsError(try phone.open(sealed.data), "A reflected packet has the wrong direction")
        let wrongKey = try PeerMessageCodec(key: Data(repeating: 8, count: 32), service: service, nonce: "connection-1", direction: .toPhone)
        XCTAssertThrowsError(try wrongKey.open(sealed.data))
        let wrongSession = try PeerMessageCodec(key: key, service: "another-session", nonce: "connection-1", direction: .toPhone)
        XCTAssertThrowsError(try wrongSession.open(sealed.data))
        var tampered = sealed.data; tampered[3] = PeerChannel.assets.rawValue
        XCTAssertThrowsError(try mac.open(tampered))
        tampered = sealed.data; tampered[tampered.count - 1] ^= 1
        XCTAssertThrowsError(try mac.open(tampered))
        XCTAssertEqual(try mac.open(sealed.data).message["kind"]?.string, "hello", "Bad authentication must not advance receive sequence")
    }
    func testPlaintextInvalidKeysAndOversizedMessagesAreRejected() throws {
        let (phone, mac) = try codecs()
        XCTAssertThrowsError(try mac.open(Data("{\"kind\":\"hello\"}".utf8)))
        XCTAssertThrowsError(try mac.open(Data(repeating: 0, count: FrameDecoder.maximumSize + 41)))
        XCTAssertThrowsError(try phone.seal(["data": .string(String(repeating: "a", count: FrameDecoder.maximumSize))], channel: .assets))
        XCTAssertThrowsError(try PeerMessageCodec(key: Data(), service: service, nonce: "x", direction: .toMac))
    }
    func testMultipeerQRIsExplicitAndCannotDowngradeLANPairing() throws {
        var url = URLComponents(string: "nodus-presenter://pair")!
        url.queryItems = [URLQueryItem(name: "version", value: "3"), URLQueryItem(name: "transport", value: "multipeer"),
                          URLQueryItem(name: "service", value: service), URLQueryItem(name: "key", value: key.base64EncodedString())]
        let pairing = try Pairing(url: url.url!)
        XCTAssertTrue(pairing.usesMultipeer)
        XCTAssertNil(pairing.lan)
        for extra in [URLQueryItem(name: "transport", value: "lan"), URLQueryItem(name: "port", value: "80"), URLQueryItem(name: "hosts", value: "127.0.0.1")] {
            var bad = url; bad.queryItems!.append(extra)
            XCTAssertThrowsError(try Pairing(url: bad.url!))
        }
        url.queryItems!.removeAll { $0.name == "transport" }
        XCTAssertThrowsError(try Pairing(url: url.url!))
    }
}
