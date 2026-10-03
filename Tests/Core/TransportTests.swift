import XCTest
import Network
@testable import PresenterCore

final class TransportTests: XCTestCase {
    func testMacQRUsesAnUnscopedBonjourEndpointWithPeerToPeerEnabled() throws {
        let service = "nodus-12345678-1234-1234-1234-123456789abc"
        guard case let .service(name, type, domain, interface) = PresenterTLS.macEndpoint(service: service) else {
            return XCTFail("Mac QR must resolve a Bonjour service, not a cached IP address")
        }
        XCTAssertEqual(name, service)
        XCTAssertEqual(type, Pairing.serviceType)
        XCTAssertEqual(domain, "local.")
        XCTAssertNil(interface, "Do not pin TLS to a failing infrastructure/VPN interface")
        XCTAssertTrue(PresenterTLS.parameters(key: Data(repeating: 7, count: 32), identity: service).includePeerToPeer)
    }
}
