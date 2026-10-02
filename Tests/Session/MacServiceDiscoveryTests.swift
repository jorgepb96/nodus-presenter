import XCTest
import Network
import PresenterCore
@testable import NodusPresenter

@MainActor final class MacServiceDiscoveryTests: XCTestCase {
    private let service = "nodus-12345678-1234-1234-1234-123456789abc"

    func testSelectsOnlyQRServiceAndStopsBrowsingBeforeConnecting() {
        let browser = FakeMacBrowser()
        let discovery = MacServiceDiscovery(makeBrowser: { browser })
        var results: [NWEndpoint] = []
        discovery.start(service: service) { outcome in
            XCTAssertTrue(browser.cancelled, "Peer browsing must stop before connection startup")
            if case .found(let endpoint) = outcome { results.append(endpoint) }
        }
        let deliver = browser.resultsChanged!
        deliver([.service(name: "another-session", type: Pairing.serviceType, domain: "local.", interface: nil)])
        XCTAssertTrue(results.isEmpty)
        let selected = NWEndpoint.service(name: service, type: Pairing.serviceType, domain: "local.", interface: nil)
        deliver([selected])
        deliver([selected]) // already queued duplicate callback
        XCTAssertEqual(results, [selected])
    }

    func testCancelledAttemptCannotCompleteANewAttempt() {
        var browsers: [FakeMacBrowser] = []
        let discovery = MacServiceDiscovery(makeBrowser: {
            let browser = FakeMacBrowser(); browsers.append(browser); return browser
        })
        var outcomes = 0
        discovery.start(service: service) { _ in XCTFail("Old discovery must stay cancelled") }
        let staleResult = browsers[0].resultsChanged!
        let staleFailure = browsers[0].stateChanged!
        discovery.start(service: service) { _ in outcomes += 1 }
        staleResult([.service(name: service, type: Pairing.serviceType, domain: "local.", interface: nil)])
        staleFailure(.failed(.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection))))
        XCTAssertTrue(browsers[0].cancelled)
        XCTAssertFalse(browsers[1].cancelled)
        XCTAssertEqual(outcomes, 0)
        discovery.cancel()
    }

    func testOnlyAnExplicitPolicyErrorIsReportedAsUnavailablePermissionAfterWaiting() async {
        let browser = FakeMacBrowser()
        let discovery = MacServiceDiscovery(makeBrowser: { browser })
        var failures: [NWError] = []
        let stopped = expectation(description: "Persistent policy denial after bounded wait")
        discovery.start(service: service, timeout: .milliseconds(50)) {
            if case .failed(let error) = $0 { failures.append(error); stopped.fulfill() }
        }
        browser.stateChanged?(.waiting(.posix(.ENETDOWN)))
        XCTAssertFalse(browser.cancelled, "A temporary connectivity wait is not denied permission")
        let denied = NWError.dns(DNSServiceErrorType(kDNSServiceErr_PolicyDenied))
        browser.stateChanged?(.waiting(denied))
        XCTAssertTrue(failures.isEmpty, "The user may not have answered the permission prompt yet")
        XCTAssertFalse(browser.cancelled)
        await fulfillment(of: [stopped], timeout: 2)
        XCTAssertEqual(failures, [denied])
        XCTAssertTrue(browser.cancelled)
        XCTAssertFalse(MacServiceDiscovery.isPermissionDenied(.dns(DNSServiceErrorType(kDNSServiceErr_DefunctConnection))))
    }

    func testGrantingTheFirstPermissionCanRecoverTheWaitingBrowser() {
        let browser = FakeMacBrowser()
        let discovery = MacServiceDiscovery(makeBrowser: { browser })
        var found = false
        discovery.start(service: service) { if case .found = $0 { found = true } else { XCTFail("Grant should recover browsing") } }
        browser.stateChanged?(.waiting(.dns(DNSServiceErrorType(kDNSServiceErr_PolicyDenied))))
        XCTAssertFalse(browser.cancelled)
        browser.stateChanged?(.ready)
        browser.resultsChanged?([.service(name: service, type: Pairing.serviceType, domain: "local.", interface: nil)])
        XCTAssertTrue(found)
        XCTAssertTrue(browser.cancelled)
    }

    func testReturningFromThePermissionDialogRestartsOnlyAnAlreadyStoppedAttempt() {
        var browsers: [FakeMacBrowser] = []
        let discovery = MacServiceDiscovery(makeBrowser: {
            let browser = FakeMacBrowser(); browsers.append(browser); return browser
        })
        let session = PresenterSession(serviceDiscovery: discovery)
        defer { session.disconnect() }
        session.connect(url: qr)
        session.sceneChanged(.inactive)
        browsers[0].stateChanged?(.failed(.dns(DNSServiceErrorType(kDNSServiceErr_PolicyDenied))))
        XCTAssertTrue(browsers[0].cancelled)
        XCTAssertNotNil(session.errorMessage)
        session.sceneChanged(.active)
        XCTAssertEqual(browsers.count, 2)
        XCTAssertNil(session.errorMessage)
        session.sceneChanged(.active)
        XCTAssertEqual(browsers.count, 2)
    }

    func testNoResultHasABoundedDeadlineAndStopsBrowser() async {
        let browser = FakeMacBrowser()
        let discovery = MacServiceDiscovery(makeBrowser: { browser })
        let completed = expectation(description: "Bounded discovery allows direct-resolution fallback")
        discovery.start(service: service, timeout: .milliseconds(50)) { outcome in
            if case .unavailable = outcome { completed.fulfill() }
            else { XCTFail("No result is unavailable, not a policy denial") }
            XCTAssertTrue(browser.cancelled)
        }
        await fulfillment(of: [completed], timeout: 2)
    }

    func testPermissionDenialStopsRetriesUntilReturningFromSettings() async throws {
        var browsers: [FakeMacBrowser] = []
        let discovery = MacServiceDiscovery(makeBrowser: {
            let browser = FakeMacBrowser(); browsers.append(browser); return browser
        })
        let session = PresenterSession(serviceDiscovery: discovery)
        defer { session.disconnect() }
        session.connect(url: qr)
        browsers[0].stateChanged?(.failed(.dns(DNSServiceErrorType(kDNSServiceErr_PolicyDenied))))
        try await Task.sleep(for: .milliseconds(1200))
        XCTAssertEqual(browsers.count, 1, "Permission denial must not retry indefinitely")
        XCTAssertFalse(session.connected)
        XCTAssertNotNil(session.errorMessage)
        session.sceneChanged(.background)
        session.sceneChanged(.inactive); session.sceneChanged(.active)
        XCTAssertEqual(browsers.count, 2, "Returning from Settings starts fresh discovery")
    }

    func testSessionKeepsOneBrowserThroughActivationAndCancelsItInBackground() {
        var browsers: [FakeMacBrowser] = []
        let discovery = MacServiceDiscovery(makeBrowser: {
            let browser = FakeMacBrowser(); browsers.append(browser); return browser
        })
        let session = PresenterSession(serviceDiscovery: discovery)
        defer { session.disconnect() }
        session.connect(url: qr)
        session.sceneChanged(.active)
        session.sceneChanged(.inactive); session.sceneChanged(.active)
        XCTAssertEqual(browsers.count, 1)
        session.sceneChanged(.background)
        XCTAssertTrue(browsers[0].cancelled)
        session.sceneChanged(.inactive); session.sceneChanged(.active)
        XCTAssertEqual(browsers.count, 2)
        session.disconnect()
        XCTAssertTrue(browsers[1].cancelled)
    }

    private var qr: URL {
        var components = URLComponents(string: "nodus-presenter://pair")!
        components.queryItems = [URLQueryItem(name: "version", value: "1"), URLQueryItem(name: "service", value: service),
                                 URLQueryItem(name: "key", value: Data(repeating: 47, count: 32).base64EncodedString())]
        return components.url!
    }
}

@MainActor private final class FakeMacBrowser: MacServiceBrowsing {
    var stateChanged: ((NWBrowser.State) -> Void)?
    var resultsChanged: (([NWEndpoint]) -> Void)?
    var cancelled = false
    func start() { stateChanged?(.ready) }
    func cancel() { cancelled = true }
}
