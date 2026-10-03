import XCTest
import Network
import Combine
import UIKit
import CryptoKit
import PresenterCore
@testable import NodusPresenter

/// Actual iOS session + TLS-PSK sockets. Loopback does not validate physical AWDL.
@MainActor final class ConnectionRecoveryTests: XCTestCase {
    func testRealBonjourDiscoveryFindsTheAdvertisedQRService() async throws {
        let server = try MacFixture(advertise: true)
        defer { server.stop() }
        try await server.start()
        let discovery = MacServiceDiscovery()
        defer { discovery.cancel() }
        let found = expectation(description: "actual NWBrowser discovers advertised QR service")
        discovery.start(service: server.service) { outcome in
            if case .found(let endpoint) = outcome,
               case .service(let name, let type, _, _) = endpoint {
                XCTAssertEqual(name, server.service)
                XCTAssertEqual(type, Pairing.serviceType)
            } else { XCTFail("Local Bonjour did not return the advertised test service") }
            found.fulfill()
        }
        await fulfillment(of: [found], timeout: 12)
        // TLS/hello and lifecycle are exercised below with loopback sockets.
        // Do not treat same-host Bonjour or Simulator as a physical-radio test.
    }

    func testStalledTLSUsesAlternativeOnceAndRejectsLateLoserCallbacks() async throws {
        let stalled = try MacFixture(acceptDelay: .seconds(5))
        let alternative = try MacFixture(identity: stalled.service)
        defer { stalled.stop(); alternative.stop() }
        try await stalled.start(); try await alternative.start()
        let session = PresenterSession()
        defer { session.disconnect() }
        session.connectionEndpointForTesting = stalled.endpoint
        session.connectionAlternativesForTesting = [alternative.endpoint, alternative.endpoint]
        alternative.onHello = { channel, _ in if channel == "control" { alternative.sendState() } }
        let connected = expectation(description: "delayed alternative completes actual TLS and hello")
        let subscription = session.$connected.filter { $0 }.prefix(1).sink { _ in connected.fulfill() }
        defer { subscription.cancel() }
        session.connect(url: stalled.url)
        let loser = try XCTUnwrap(session.controlForTesting)
        let queuedState = try XCTUnwrap(loser.onState)
        let queuedMessage = try XCTUnwrap(loser.onMessage)
        await fulfillment(of: [connected], timeout: 8)
        XCTAssertEqual(session.controlForTesting?.connection.endpoint, alternative.endpoint)
        XCTAssertEqual(alternative.hellos.filter { $0 == "control" }.count, 1)
        XCTAssertTrue(stalled.hellos.isEmpty)
        XCTAssertNil(loser.onState)
        queuedState(.failed(.posix(.ECONNRESET)))
        var stale = PresenterState(); stale.presenting = true; stale.totalSlides = 8; stale.currentSlide = 7
        let raw = try JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(stale))
        queuedMessage(["kind": .string("update"), "state": raw])
        XCTAssertTrue(session.connected)
        XCTAssertEqual(session.state.currentSlide, 3)
        XCTAssertEqual(session.assetsForTesting?.connection.endpoint, session.controlForTesting?.connection.currentPath?.remoteEndpoint)
    }

    func testHealthyNormalPathCancelsAlternativeBeforeItStarts() async throws {
        let primary = try MacFixture()
        let alternative = try MacFixture(identity: primary.service)
        defer { primary.stop(); alternative.stop() }
        try await primary.start(); try await alternative.start()
        let session = PresenterSession()
        defer { session.disconnect() }
        session.connectionEndpointForTesting = primary.endpoint
        session.connectionAlternativesForTesting = [alternative.endpoint]
        primary.onHello = { channel, _ in if channel == "control" { primary.sendState() } }
        let connected = expectation(description: "normal TLS path wins its head start")
        let subscription = session.$connected.filter { $0 }.prefix(1).sink { _ in connected.fulfill() }
        defer { subscription.cancel() }
        session.connect(url: primary.url)
        await fulfillment(of: [connected], timeout: 5)
        try await Task.sleep(for: .milliseconds(2300))
        XCTAssertTrue(session.connected)
        XCTAssertTrue(alternative.hellos.isEmpty)
        XCTAssertEqual(primary.hellos.filter { $0 == "control" }.count, 1)
    }

    func testDisconnectCancelsTheDelayedAlternative() async throws {
        let primary = try MacFixture(acceptDelay: .seconds(5))
        let alternative = try MacFixture(identity: primary.service)
        defer { primary.stop(); alternative.stop() }
        try await primary.start(); try await alternative.start()
        let session = PresenterSession()
        session.connectionEndpointForTesting = primary.endpoint
        session.connectionAlternativesForTesting = [alternative.endpoint]
        session.connect(url: primary.url)
        session.disconnect()
        try await Task.sleep(for: .milliseconds(2300))
        XCTAssertFalse(session.connected)
        XCTAssertFalse(session.isPairing)
        XCTAssertTrue(alternative.hellos.isEmpty)
        XCTAssertNil(session.controlForTesting)
    }

    func testPermissionDialogActivationDoesNotReplaceThePendingTLSConnection() async throws {
        let server = try MacFixture()
        defer { server.stop() }
        try await server.start()
        let session = PresenterSession()
        defer { session.disconnect() }
        session.connectionEndpointForTesting = server.endpoint
        let hello = expectation(description: "one control handshake")
        server.onHello = { channel, _ in if channel == "control" { hello.fulfill() } }
        let connected = expectation(description: "pending control receives valid state")
        let subscription = session.$connected.filter { $0 }.prefix(1).sink { _ in connected.fulfill() }
        defer { subscription.cancel() }
        session.connect(url: server.url)
        session.sceneChanged(.active)
        await fulfillment(of: [hello], timeout: 5)
        session.sceneChanged(.inactive); session.sceneChanged(.active)
        try await Task.sleep(for: .milliseconds(200))
        server.sendState()
        await fulfillment(of: [connected], timeout: 5)
        XCTAssertEqual(server.hellos.filter { $0 == "control" }.count, 1)
        XCTAssertTrue(session.connected)
    }

    func testBackgroundResumeReconnectsOnceWithoutLosingPrivateReading() async throws {
        let server = try MacFixture()
        defer { server.stop() }
        try await server.start()
        let session = PresenterSession()
        defer { session.disconnect() }
        session.connectionEndpointForTesting = server.endpoint
        server.onHello = { channel, _ in if channel == "control" { server.sendState() } }
        let first = expectation(description: "initial authenticated state")
        let initialSubscription = session.$connected.filter { $0 }.prefix(1).sink { _ in first.fulfill() }
        session.connect(url: server.url)
        await fulfillment(of: [first], timeout: 5)
        initialSubscription.cancel()
        session.togglePreview(); session.previewNextSlide()
        session.sceneChanged(.background)
        XCTAssertFalse(session.connected)
        let resumed = expectation(description: "authenticated state after real background resume")
        let subscription = session.$connected.filter { $0 }.prefix(1).sink { _ in resumed.fulfill() }
        defer { subscription.cancel() }
        session.sceneChanged(.inactive); session.sceneChanged(.active)
        session.sceneChanged(.active)
        await fulfillment(of: [resumed], timeout: 5)
        XCTAssertEqual(server.hellos.filter { $0 == "control" }.count, 2)
        XCTAssertTrue(session.localPreview)
        XCTAssertEqual(session.displayedSlide, 4)
    }

    func testViabilityLossReauthenticatesOnceAndPreservesPrivateReading() async throws {
        let server = try MacFixture()
        defer { server.stop() }
        try await server.start()
        let session = PresenterSession()
        defer { session.disconnect() }
        session.connectionEndpointForTesting = server.endpoint
        let first = expectation(description: "first authenticated connection")
        let reconnected = expectation(description: "fresh TLS and state after route loss")
        var controls = 0
        server.onHello = { channel, _ in
            guard channel == "control" else { return }
            controls += 1
            server.sendState()
        }
        let subscription = session.$connected.filter { $0 }.sink { _ in
            if controls == 1 { first.fulfill() }
            else { reconnected.fulfill() }
        }
        defer { subscription.cancel() }
        session.connect(url: server.url)
        await fulfillment(of: [first], timeout: 5)
        session.togglePreview(); session.previewNextSlide()
        let oldControl = try XCTUnwrap(session.controlForTesting)
        let queuedViability = try XCTUnwrap(oldControl.onViabilityChanged)
        let queuedMessage = try XCTUnwrap(oldControl.onMessage)
        // Inject Network's route-loss event; real radio loss cannot be simulated.
        // Reconnection, authentication and state still use actual TLS sockets.
        queuedViability(false)
        XCTAssertFalse(session.connected, "Do not leave a dead route green for twelve seconds")
        XCTAssertNil(oldControl.onViabilityChanged)
        queuedViability(false) // duplicate event must not queue a second retry
        await fulfillment(of: [reconnected], timeout: 5)
        queuedViability(false) // old generation must not close the replacement
        queuedMessage(["kind": .string("ended")])
        XCTAssertTrue(session.connected)
        XCTAssertEqual(controls, 2)
        XCTAssertTrue(session.localPreview)
        XCTAssertEqual(session.displayedSlide, 4)
    }

    func testInitialNonViabilityDoesNotReplaceAnUnauthenticatedAttempt() async throws {
        let server = try MacFixture()
        defer { server.stop() }
        try await server.start()
        let session = PresenterSession()
        defer { session.disconnect() }
        session.connectionEndpointForTesting = server.endpoint
        let hello = expectation(description: "pending control hello")
        server.onHello = { channel, _ in if channel == "control" { hello.fulfill() } }
        session.connect(url: server.url)
        let control = try XCTUnwrap(session.controlForTesting)
        control.onViabilityChanged?(false)
        await fulfillment(of: [hello], timeout: 5)
        control.onViabilityChanged?(false)
        try await Task.sleep(for: .milliseconds(1200))
        XCTAssertTrue(session.controlForTesting === control)
        XCTAssertEqual(server.hellos.filter { $0 == "control" }.count, 1)
    }

    func testSlowTLSCanFinishAfterTheOldTwelveSecondDiscoveryDeadline() async throws {
        let server = try MacFixture(acceptDelay: .seconds(13))
        defer { server.stop() }
        try await server.start()
        let session = PresenterSession()
        defer { session.disconnect() }
        session.connectionEndpointForTesting = server.endpoint
        let connected = expectation(description: "Slow TLS still reaches valid presenter state")
        let subscription = session.$connected.filter { $0 }.prefix(1).sink { _ in connected.fulfill() }
        defer { subscription.cancel() }
        server.onHello = { channel, _ in if channel == "control" { server.sendState() } }
        let started = ContinuousClock.now
        session.connect(url: server.url)
        await fulfillment(of: [connected], timeout: 20)
        XCTAssertTrue(session.connected)
        XCTAssertGreaterThanOrEqual(started.duration(to: .now), .seconds(12))
        XCTAssertEqual(server.hellos.filter { $0 == "control" }.count, 1)
    }

    func testAssetsStartOnlyAfterTheControlSessionIsAuthenticated() async throws {
        let server = try MacFixture()
        defer { server.stop() }
        try await server.start()
        let session = PresenterSession()
        defer { session.disconnect() }
        session.connectionEndpointForTesting = server.endpoint
        let control = expectation(description: "TLS control hello")
        let assets = expectation(description: "assets hello after valid state")
        server.onHello = { channel, _ in
            if channel == "control" { control.fulfill() }
            if channel == "assets" { assets.fulfill() }
        }
        session.connect(url: server.url)
        await fulfillment(of: [control], timeout: 5)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertFalse(session.connected, "TLS alone is not an authenticated presenter state")
        XCTAssertEqual(server.hellos, ["control"], "Do not compete with control startup using a second TLS connection")
        server.sendState()
        await fulfillment(of: [assets], timeout: 5)
        XCTAssertTrue(session.connected)
        XCTAssertEqual(session.state.totalSlides, 8)
    }

    func testAssetsUseAuthenticatedPeerEndpointAndReceiveImageAndVerifiedPDF() async throws {
        let server = try MacFixture()
        defer { server.stop() }
        try await server.start()
        server.assetVersion = UUID().uuidString
        let session = PresenterSession()
        defer { session.disconnect() }
        session.connectionEndpointForTesting = server.endpoint
        let imageReceived = expectation(description: "thumbnail decoded")
        let pdfReceived = expectation(description: "PDF downloaded and SHA256 verified")
        let imageSubscription = session.$imageRevision.dropFirst().prefix(1).sink { _ in imageReceived.fulfill() }
        let pdfSubscription = session.$pdfDocument.compactMap { $0 }.prefix(1).sink { document in
            XCTAssertEqual(document.pageCount, 1)
            pdfReceived.fulfill()
        }
        defer { imageSubscription.cancel(); pdfSubscription.cancel() }
        let thumbnail = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 9)).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 16, height: 9))
        }.pngData()!
        let pdf = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 160, height: 90)).pdfData { $0.beginPage() }
        server.onHello = { channel, _ in if channel == "control" { server.sendState() } }
        server.onAssetRequest = { message, connection in
            if message["kind"]?.string == "image" {
                connection.send(["kind": .string("image"), "page": message["page"]!,
                                 "assetVersion": .string(server.assetVersion!), "data": .string(thumbnail.base64EncodedString())])
            } else if message["kind"]?.string == "pdf" {
                let version = JSONValue.string(server.assetVersion!)
                connection.send(["kind": .string("pdfBegin"), "assetVersion": version, "size": .number(Double(pdf.count)), "offset": .number(0)])
                connection.send(["kind": .string("pdfChunk"), "assetVersion": version, "offset": .number(0), "data": .string(pdf.base64EncodedString())])
                let hash = SHA256.hash(data: pdf).map { String(format: "%02x", $0) }.joined()
                connection.send(["kind": .string("pdfEnd"), "assetVersion": version, "sha256": .string(hash)])
            }
        }
        session.connect(url: server.url)
        await fulfillment(of: [imageReceived, pdfReceived], timeout: 8)
        let control = try XCTUnwrap(session.controlForTesting)
        let assets = try XCTUnwrap(session.assetsForTesting)
        XCTAssertEqual(assets.connection.endpoint, control.connection.currentPath?.remoteEndpoint)
        XCTAssertNotNil(session.image(for: 3))
        XCTAssertTrue(session.connected)
    }

    func testBrokenAssetsReconnectWithoutDroppingControlOrPrivateReading() async throws {
        let server = try MacFixture()
        defer { server.stop() }
        try await server.start()
        let session = PresenterSession()
        defer { session.disconnect() }
        session.connectionEndpointForTesting = server.endpoint
        let firstAssets = expectation(description: "first assets channel")
        let recoveredAssets = expectation(description: "recovered assets channel")
        var assetCount = 0
        server.onHello = { channel, connection in
            if channel == "control" { server.sendState() }
            if channel == "assets" {
                assetCount += 1
                if assetCount == 1 { firstAssets.fulfill(); connection.cancel() }
                else { recoveredAssets.fulfill() }
            }
        }
        session.connect(url: server.url)
        await fulfillment(of: [firstAssets], timeout: 5)
        session.togglePreview(); session.previewNextSlide()
        XCTAssertTrue(session.localPreview)
        let navigation = expectation(description: "control still carries navigation")
        server.onAction = { action in
            if action["type"]?.string == "blackScreen", action["enabled"]?.bool == true { navigation.fulfill() }
        }
        session.send(["type": .string("blackScreen"), "enabled": .bool(true)])
        await fulfillment(of: [navigation, recoveredAssets], timeout: 6)
        XCTAssertTrue(session.connected, "A broken PDF channel must not turn the connection red")
        XCTAssertEqual(server.hellos.filter { $0 == "control" }.count, 1)
        XCTAssertTrue(session.localPreview)
        XCTAssertEqual(session.displayedSlide, 4)
    }

    func testDisconnectCancelsAnAssetsRetryAndRejectsLateUpdates() async throws {
        let server = try MacFixture()
        defer { server.stop() }
        try await server.start()
        let session = PresenterSession()
        session.connectionEndpointForTesting = server.endpoint
        let assets = expectation(description: "assets channel dropped")
        server.onHello = { channel, connection in
            if channel == "control" { server.sendState() }
            if channel == "assets" { connection.cancel(); assets.fulfill() }
        }
        session.connect(url: server.url)
        await fulfillment(of: [assets], timeout: 5)
        session.disconnect()
        server.sendState()
        try await Task.sleep(for: .milliseconds(1300))
        XCTAssertFalse(session.connected)
        XCTAssertFalse(session.isPairing)
        XCTAssertEqual(server.hellos.filter { $0 == "assets" }.count, 1)
        XCTAssertEqual(session.state.totalSlides, 0)
    }
}

@MainActor private final class MacFixture {
    let service: String
    let key = Data(repeating: 47, count: 32)
    private let listener: NWListener
    private let acceptDelay: Duration?
    private var clients: [FramedConnection] = []
    private var stopped = false
    private var control: FramedConnection?
    var hellos: [String] = []
    var onHello: ((String, FramedConnection) -> Void)?
    var onAction: ((Message) -> Void)?
    var assetVersion: String?
    var onAssetRequest: ((Message, FramedConnection) -> Void)?
    var endpoint: NWEndpoint { .hostPort(host: "127.0.0.1", port: listener.port!) }
    var url: URL {
        var components = URLComponents(string: "nodus-presenter://pair")!
        components.queryItems = [URLQueryItem(name: "version", value: "1"), URLQueryItem(name: "service", value: service),
                                URLQueryItem(name: "key", value: key.base64EncodedString()), URLQueryItem(name: "name", value: "Test Mac")]
        return components.url!
    }
    init(acceptDelay: Duration? = nil, advertise: Bool = false, identity: String? = nil) throws {
        let identity = identity ?? "nodus-" + UUID().uuidString.lowercased()
        service = identity
        self.acceptDelay = acceptDelay
        let parameters = PresenterTLS.parameters(key: Data(repeating: 47, count: 32), identity: identity)
        if !advertise { parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any) }
        listener = try NWListener(using: parameters)
        if advertise { listener.service = NWListener.Service(name: identity, type: Pairing.serviceType) }
    }
    func start() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                switch state {
                case .ready: self?.listener.stateUpdateHandler = nil; continuation.resume()
                case .failed(let error): self?.listener.stateUpdateHandler = nil; continuation.resume(throwing: error)
                default: break
                }
                }
            }
            listener.newConnectionHandler = { [weak self] socket in
                Task { @MainActor in
                guard let self else { socket.cancel(); return }
                let client = FramedConnection(socket)
                self.clients.append(client)
                client.onMessage = { [weak self, weak client] message in
                    Task { @MainActor in
                    guard let self, let client else { return }
                    if message["kind"]?.string == "hello", let channel = message["channel"]?.string {
                        self.hellos.append(channel)
                        if channel == "control" { self.control = client }
                        self.onHello?(channel, client)
                    } else if message["kind"]?.string == "ping" { client.send(["kind": .string("pong")]) }
                    else if let action = message["action"]?.object { self.onAction?(action) }
                    else if ["image", "pdf"].contains(message["kind"]?.string ?? "") { self.onAssetRequest?(message, client) }
                    }
                }
                if let delay = self.acceptDelay { try? await Task.sleep(for: delay) }
                guard !self.stopped else { client.cancel(); return }
                client.start(queue: .main)
                }
            }
            listener.start(queue: .main)
        }
    }
    func sendState() {
        var state = PresenterState(); state.presenting = true; state.totalSlides = 8; state.currentSlide = 3
        let raw = try! JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(state))
        var message: Message = ["kind": .string("update"), "state": raw]
        if let assetVersion { message["deck"] = .object(["assetVersion": .string(assetVersion)]) }
        control?.send(message)
    }
    func stop() { stopped = true; clients.forEach { $0.cancel() }; listener.cancel() }
}
