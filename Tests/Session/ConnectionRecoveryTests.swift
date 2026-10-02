import XCTest
import Network
import Combine
import PresenterCore
@testable import NodusPresenter

/// Actual iOS session + TLS-PSK sockets. Loopback does not validate physical AWDL.
@MainActor final class ConnectionRecoveryTests: XCTestCase {
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
            if action["type"]?.string == "setBlackScreen" { navigation.fulfill() }
        }
        session.send(["type": .string("setBlackScreen"), "value": .bool(true)])
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
    let service = "nodus-12345678-1234-1234-1234-123456789abc"
    let key = Data(repeating: 47, count: 32)
    private let listener: NWListener
    private let acceptDelay: Duration?
    private var clients: [FramedConnection] = []
    private var control: FramedConnection?
    var hellos: [String] = []
    var onHello: ((String, FramedConnection) -> Void)?
    var onAction: ((Message) -> Void)?
    var endpoint: NWEndpoint { .hostPort(host: "127.0.0.1", port: listener.port!) }
    var url: URL {
        var components = URLComponents(string: "nodus-presenter://pair")!
        components.queryItems = [URLQueryItem(name: "version", value: "1"), URLQueryItem(name: "service", value: service),
                                URLQueryItem(name: "key", value: key.base64EncodedString()), URLQueryItem(name: "name", value: "Test Mac")]
        return components.url!
    }
    init(acceptDelay: Duration? = nil) throws {
        self.acceptDelay = acceptDelay
        let parameters = PresenterTLS.parameters(key: Data(repeating: 47, count: 32), identity: "nodus-12345678-1234-1234-1234-123456789abc")
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
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
                    }
                }
                if let delay = self.acceptDelay { try? await Task.sleep(for: delay) }
                client.start(queue: .main)
                }
            }
            listener.start(queue: .main)
        }
    }
    func sendState() {
        var state = PresenterState(); state.presenting = true; state.totalSlides = 8; state.currentSlide = 3
        let raw = try! JSONDecoder().decode(JSONValue.self, from: JSONEncoder().encode(state))
        control?.send(["kind": .string("update"), "state": raw])
    }
    func stop() { clients.forEach { $0.cancel() }; listener.cancel() }
}
