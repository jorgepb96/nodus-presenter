import SwiftUI
@preconcurrency import Network
import PDFKit
import CryptoKit
import PresenterCore

struct InkStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    let color: String
    let width: Double
}

@MainActor final class PresenterSession: ObservableObject {
    @Published var state = PresenterState()
    @Published var status = L10n.text("Not connected")
    @Published var connected = false
    @Published var isDemo = false
    @Published var deckName = ""
    @Published var macName = "Nodus"
    @Published var notes: [String: String] = [:]
    @Published var videos: [String: JSONValue] = [:]
    @Published var errorMessage: String?
    @Published var localPreview = false
    @Published var localSlide = 1
    @Published var volume: Double = 50
    @Published var imageRevision = 0
    @Published var toolPosition = CGPoint(x: 0.62, y: 0.46)
    @Published var strokes: [InkStroke] = []
    @Published var showSlides = false
    @Published var showTools = false
    @Published var notesFont: Double = 18
    @Published var pdfDocument: PDFDocument?
    var isPairing: Bool { pairing != nil }
    private var foreground = true
    private var wasBackgrounded = false
    private var wasInactive = false
    private var awaitingNetworkPermission = false
    private var macPermissionWaiting = false
    private let serviceDiscovery: MacServiceDiscovery
    private var connectionTimeout: Task<Void, Never>?
    private var pairing: Pairing?
    private var macEndpoint: NWEndpoint?
    private var control: FramedConnection?
    private var assets: FramedConnection?
    private var multipeer: MultipeerPresenterConnection?
    private var assetsReady = false
    private var generation = UUID()
    private var reconnectTask: Task<Void, Never>?
    private var assetsReconnectTask: Task<Void, Never>?
    private var assetsTimeout: Task<Void, Never>?
    private var assetRetries = 0
    private var retries = 0
    private var lanCandidates: [FramedConnection] = []
    private var macCandidates: [FramedConnection] = []
    private var macFallbackTask: Task<Void, Never>?
    private var heartbeat: Timer?
    private var lastReceipt = Date()
    private let deviceID = UUID().uuidString
    private var imageCache = NSCache<NSString, UIImage>()
    private var pendingImages = Set<String>()
    private var assetVersion = ""
    private var pdfFile: FileHandle?
    private var pdfURL: URL?
    private var pdfOffset = 0
    private var expectedPDFSize = 0
    private var downloadVersion = ""
    private var downloadInFlight = false
    private var lastToolSent = Date.distantPast
    private lazy var motionSender = DisplayLinkMotionSender { [weak self] action in
        self?.sendControl(["kind": .string("action"), "commandId": .string(UUID().uuidString), "action": .object(action)])
    }
    private var drawing = false
    #if DEBUG && targetEnvironment(simulator)
    // Hosted regression tests use the same TLS/hello/recovery flow over loopback.
    var connectionEndpointForTesting: NWEndpoint?
    var connectionAlternativesForTesting: [NWEndpoint] = []
    var controlForTesting: FramedConnection? { control }
    var assetsForTesting: FramedConnection? { assets }
    #endif

    init(serviceDiscovery: MacServiceDiscovery? = nil) {
        self.serviceDiscovery = serviceDiscovery ?? MacServiceDiscovery()
        let cache = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        if let files = try? FileManager.default.contentsOfDirectory(at: cache, includingPropertiesForKeys: [.contentModificationDateKey]) {
            for file in files where file.lastPathComponent.hasPrefix("presenter-") {
                if let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate, Date().timeIntervalSince(date) > 7 * 86400 { try? FileManager.default.removeItem(at: file) }
            }
        }
        imageCache.totalCostLimit = 24 * 1024 * 1024
        heartbeat = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        let args = ProcessInfo.processInfo.arguments
        #if DEBUG
        ConnectionDiagnostics.record("launch-build-\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown")-wirelessQA-\(ConnectionDiagnostics.wirelessQA)", channel: "app")
        ConnectionDiagnostics.startPathMonitoring()
        // Physical QA imports the already visible Mac QR without exposing secrets
        // in launch arguments. The file is consumed once; release excludes this.
        if ConnectionDiagnostics.enabled, args.contains("--device-pair-file") {
            let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("presenter-qa-pair.txt")
            if let text = try? String(contentsOf: file, encoding: .utf8) {
                try? FileManager.default.removeItem(at: file)
                if let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) { connect(url: url) }
            }
        }
        #endif
        #if DEBUG && targetEnvironment(simulator)
        // An ignored, private file lets connected QA avoid putting QR secrets in argv/logs.
        if let index = args.firstIndex(of: "--simulator-pair-file"), args.count > index + 1,
           let text = try? String(contentsOfFile: args[index + 1], encoding: .utf8),
           let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) { connect(url: url) }
        #endif
        if let index = args.firstIndex(of: "--pair"), args.count > index + 1, let url = URL(string: args[index + 1]) { connect(url: url) }
        if args.contains("--demo") {
            enterDemo()
            if args.contains("--video") { state.currentSlide = 4; localSlide = 4 }
            if args.contains("--tools") { state.toolMode = "flashlight"; showTools = true }
            if args.contains("--slides") { showSlides = true }
            if args.contains("--spotlight") { state.toolMode = "flashlight" }
        }
    }
    var displayedSlide: Int { localPreview ? localSlide : state.currentSlide }
    var canControl: Bool { (connected || isDemo) && state.presenting }
    var note: String { notes[String(displayedSlide)] ?? "" }
    var timerText: String { String(format: "%02d:%02d", state.timerSeconds / 60, state.timerSeconds % 60) }
    var selectedTool: Tool? { state.toolMode.flatMap(Tool.init(rawValue:)) }
    var hasCurrentVideo: Bool { videos[String(state.currentSlide)] != nil }
    var isLANConnection: Bool { pairing?.lan != nil }
    var volumeTitle: String { isLANConnection ? L10n.text("Video volume") : L10n.text("Mac volume") }

    func enterDemo() {
        disconnect()
        isDemo = true; connected = false; status = L10n.text("Demo · Not connected to Nodus")
        macName = L10n.text("Demo Mac"); deckName = L10n.text("Knowledge networks")
        pdfDocument = DemoDeck.make()
        state = PresenterState(); state.presenting = true; state.pdfId = "demo"
        state.totalSlides = pdfDocument?.pageCount ?? 8; state.currentSlide = 3; state.timerSeconds = 522
        state.toolColor = "#8b5cf6"
        notes = DemoDeck.notes; videos = [:]
        localSlide = state.currentSlide; assetVersion = "demo"; imageRevision += 1
    }
    func connect(url: URL) {
        // The public demo QR uses the same scanner and URL entry points as pairing.
        if url.absoluteString == "nodus-presenter://demo" {
            errorMessage = nil
            enterDemo()
            return
        }
        do {
            let newPairing = try Pairing(url: url)
            disconnect(); pairing = newPairing; macName = newPairing.name
            retries = 0; beginDiscovery()
        } catch { errorMessage = L10n.text("This QR code is not a Nodus Presenter app session. Choose App iPhone–iPad in Nodus.") }
    }
    func disconnect() {
        motionSender.cancel()
        serviceDiscovery.cancel()
        generation = UUID(); reconnectTask?.cancel(); reconnectTask = nil; connectionTimeout?.cancel(); connectionTimeout = nil
        cancelAssetRecovery(); cancelMacCandidates(); macEndpoint = nil
        control?.cancel(); assets?.cancel(); control = nil; assets = nil
        multipeer?.cancel(); multipeer = nil
        lanCandidates.forEach { $0.cancel() }; lanCandidates.removeAll()
        assetsReady = false; connected = false; isDemo = false; pairing = nil
        awaitingNetworkPermission = false; macPermissionWaiting = false
        state = PresenterState(); deckName = ""; notes = [:]; videos = [:]; pdfDocument = nil
        imageCache.removeAllObjects(); pendingImages.removeAll(); strokes = []
        try? pdfFile?.close(); pdfFile = nil; pdfURL = nil; pdfOffset = 0; downloadVersion = ""; downloadInFlight = false
        localPreview = false; showTools = false; showSlides = false; status = L10n.text("Not connected")
        UIApplication.shared.isIdleTimerDisabled = false
    }
    func sceneChanged(_ phase: ScenePhase) {
        UIApplication.shared.isIdleTimerDisabled = phase == .active && (connected || isDemo)
        if phase == .inactive { wasInactive = true }
        if phase == .background { foreground = false; wasBackgrounded = true }
        if phase == .active { foreground = true }
        if phase == .background, pairing != nil {
            motionSender.cancel()
            serviceDiscovery.cancel()
            generation = UUID(); connected = false; status = L10n.text("Not connected · App in background")
            reconnectTask?.cancel(); reconnectTask = nil; connectionTimeout?.cancel(); connectionTimeout = nil
            cancelAssetRecovery(); cancelMacCandidates(); macEndpoint = nil
            control?.cancel(); control = nil; assets?.cancel(); assets = nil; assetsReady = false
            multipeer?.cancel(); multipeer = nil
            lanCandidates.forEach { $0.cancel() }; lanCandidates.removeAll()
            try? pdfFile?.close(); pdfFile = nil; downloadInFlight = false
        }
        // Permission dialogs and initial activation produce inactive/active
        // transitions too. Never replace an attempt which is still pending.
        if phase == .active {
            // A denied/expired attempt has already been cancelled. It may have
            // happened before the first permission dialog received an answer.
            let resume = wasBackgrounded || (wasInactive && awaitingNetworkPermission)
            wasBackgrounded = false; wasInactive = false
            if resume, pairing != nil, !connected, reconnectTask == nil { beginDiscovery() }
        }
    }
    private func tick() {
        if isDemo { if state.timerRunning { state.timerSeconds += 1 }; return }
        guard connected else { return }
        if Date().timeIntervalSince(lastReceipt) > 12 { scheduleReconnect(); return }
        sendControl(["kind": .string("ping")]); refreshVisibleImages()
    }
    private func beginDiscovery() {
        guard foreground, let pairing else { return }
        if awaitingNetworkPermission { errorMessage = nil }
        awaitingNetworkPermission = false; macPermissionWaiting = false
        serviceDiscovery.cancel()
        let token = UUID(); generation = token
        connected = false; status = retries == 0 ? L10n.text("Looking for Nodus…") : L10n.text("Reconnecting to Nodus…")
        if pairing.usesMultipeer {
            beginMultipeer(pairing: pairing, token: token)
            return
        }
        if let lan = pairing.lan {
            beginLAN(pairing: pairing, lan: lan, token: token)
            return
        }
        #if DEBUG && targetEnvironment(simulator)
        // Simulator Bonjour cannot always discover a service on its host Mac.
        // Connected verification still uses the QR's real TLS key and protocol.
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--simulator-endpoint"), args.count > index + 2,
           let port = UInt16(args[index + 2]), let nwPort = NWEndpoint.Port(rawValue: port) {
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(args[index + 1]), port: nwPort)
            macEndpoint = endpoint; open(endpoint: endpoint, pairing: pairing, token: token)
            return
        }
        if let endpoint = connectionEndpointForTesting {
            macEndpoint = endpoint; open(endpoint: endpoint, pairing: pairing, token: token, alternatives: connectionAlternativesForTesting)
            return
        }
        #endif
        serviceDiscovery.start(service: pairing.service) { [weak self] outcome in
            guard let self, self.generation == token else { return }
            let endpoint: NWEndpoint
            switch outcome {
            case .found(let discovered): endpoint = discovered
            case .unavailable:
                // Absence of a browse result is not proof of denied permission.
                // Keep direct resolution available after stopping the browser.
                endpoint = PresenterTLS.macEndpoint(service: pairing.service)
            case .failed(let error):
                if MacServiceDiscovery.isPermissionDenied(error) { self.localNetworkDenied() }
                else { self.scheduleReconnect() } // includes defunct Bonjour; bounded backoff
                return
            }
            self.macEndpoint = endpoint
            self.open(endpoint: endpoint, pairing: pairing, token: token, alternatives: self.serviceDiscovery.alternativeEndpoints)
        }
    }
    private func beginMultipeer(pairing: Pairing, token: UUID) {
        multipeer?.cancel()
        let connection = MultipeerPresenterConnection(pairing: pairing)
        multipeer = connection
        armMacConnectionTimeout(seconds: 30, token: token)
        connection.onConnecting = { [weak self] in
            guard let self, self.generation == token else { return }
            self.status = L10n.text("Connecting to Nodus…")
            self.armMacConnectionTimeout(seconds: 30, token: token)
        }
        connection.onReady = { [weak self, weak connection] in
            guard let self, let connection, self.generation == token, self.multipeer === connection else { return }
            self.armMacConnectionTimeout(seconds: 10, token: token)
            self.assetsReady = true
            for channel in [PeerChannel.control, .assets] {
                connection.send(["kind": .string("hello"), "version": .number(1),
                                 "channel": .string(channel == .control ? "control" : "assets"),
                                 "deviceId": .string(self.deviceID)], channel: channel)
            }
        }
        connection.onMessage = { [weak self, weak connection] message, channel in
            guard let self, let connection, self.generation == token, self.multipeer === connection else { return }
            self.receive(message, channel: channel)
        }
        connection.onFailure = { [weak self] _ in
            guard let self, self.generation == token else { return }
            self.scheduleReconnect()
        }
        connection.start()
    }
    private func sendControl(_ message: Message) {
        if let multipeer { multipeer.send(message, channel: .control) }
        else { control?.send(message) }
    }
    private func sendAssets(_ message: Message) {
        if let multipeer { multipeer.send(message, channel: .assets) }
        else { assets?.send(message) }
    }
    private func beginLAN(pairing: Pairing, lan: LANPairing, token: UUID) {
        status = L10n.text("Connecting to Nodus…")
        // Race the authenticated control connections so a VPN/virtual interface cannot
        // make scanning the QR wait through successive endpoint timeouts.
        var remaining = lan.hosts.count
        for host in lan.hosts {
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: lan.port)!)
            let candidate = FramedConnection(NWConnection(to: endpoint, using: PresenterTLS.lanParameters(fingerprint: lan.fingerprint)))
            lanCandidates.append(candidate)
            candidate.onState = { [weak self, weak candidate] value in
                guard let self, let candidate, self.generation == token else { return }
                switch value {
                case .ready:
                    candidate.send(["kind": .string("hello"), "version": .number(1), "channel": .string("control"),
                                    "deviceId": .string(self.deviceID), "key": .string(pairing.key.base64EncodedString())])
                case .failed, .cancelled:
                    remaining -= 1
                    if remaining == 0 && self.control == nil { self.scheduleReconnect() }
                default: break
                }
            }
            candidate.onMessage = { [weak self, weak candidate] message in
                guard let self, let candidate, self.generation == token, self.control == nil,
                      message["kind"]?.string == "update", let raw = message["state"],
                      (try? PresenterState.decode(raw)) != nil else { return }
                self.control = candidate
                self.lanCandidates.filter { $0 !== candidate }.forEach { $0.cancel() }
                self.lanCandidates.removeAll()
                candidate.onMessage = { [weak self] message in
                    guard let self, self.generation == token else { return }; self.receive(message, channel: "control")
                }
                candidate.onState = { [weak self] state in
                    guard let self, self.generation == token else { return }
                    if case .failed = state { self.scheduleReconnect() }
                    if case .cancelled = state { self.scheduleReconnect() }
                }
                self.receive(message, channel: "control")
                self.openLANAssets(endpoint: endpoint, pairing: pairing, lan: lan, token: token)
            }
            candidate.start(queue: .main)
        }
        connectionTimeout?.cancel()
        connectionTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, let self, self.generation == token, !self.connected else { return }
            self.errorMessage = L10n.text("Unable to reach Nodus. Check that both devices are on the same local network and that the computer’s firewall allows Nodus.")
            self.scheduleReconnect()
        }
    }
    private func openLANAssets(endpoint: NWEndpoint, pairing: Pairing, lan: LANPairing, token: UUID) {
        let connection = FramedConnection(NWConnection(to: endpoint, using: PresenterTLS.lanParameters(fingerprint: lan.fingerprint)))
        assets = connection
        connection.onState = { [weak self, weak connection] value in
            guard let self, self.generation == token else { return }
            switch value {
            case .ready:
                connection?.send(["kind": .string("hello"), "version": .number(1), "channel": .string("assets"),
                                  "deviceId": .string(self.deviceID), "key": .string(pairing.key.base64EncodedString())])
                self.assetsReady = true; self.pendingImages.removeAll(); self.refreshVisibleImages()
            case .failed, .cancelled: self.scheduleReconnect()
            default: break
            }
        }
        connection.onMessage = { [weak self] message in
            guard let self, self.generation == token else { return }; self.receive(message, channel: "assets")
        }
        connection.start(queue: .main)
    }
    private func open(endpoint: NWEndpoint, pairing: Pairing, token: UUID, alternatives: [NWEndpoint] = []) {
        status = L10n.text("Connecting to Nodus…")
        armMacConnectionTimeout(seconds: 30, token: token)
        cancelMacCandidates()
        var endpoints = [endpoint]
        for alternative in alternatives where !endpoints.contains(alternative) { endpoints.append(alternative) }
        // The normal endpoint retains its head start. Limit radio work even if
        // Bonjour exposes many interfaces. Only the first authenticated TLS path
        // sends hello; cancelled candidates never receive control of the session.
        macCandidates = endpoints.prefix(4).map { target in
            let parameters = PresenterTLS.parameters(key: pairing.key, identity: pairing.service)
            #if DEBUG
            ConnectionDiagnostics.excludeUSB(parameters)
            #endif
            return FramedConnection(NWConnection(to: target, using: parameters))
        }
        control = macCandidates.first
        for connection in macCandidates {
            connection.onViabilityChanged = { [weak self, weak connection] viable in
                guard let self, let connection, self.generation == token, self.control === connection else { return }
                #if DEBUG
                ConnectionDiagnostics.record(viable ? "viable" : "not-viable", channel: "mac-control", connection: connection.connection)
                #endif
                if !viable, self.connected { self.scheduleReconnect() }
            }
            #if DEBUG
            connection.onPathChanged = { [weak connection] in
                if let connection { ConnectionDiagnostics.record("path-changed", channel: "mac-control", connection: connection.connection) }
            }
            #endif
            connection.onState = { [weak self, weak connection] value in
                guard let self, let connection, self.generation == token,
                      self.control === connection || self.macCandidates.contains(where: { $0 === connection }) else { return }
                #if DEBUG
                ConnectionDiagnostics.record(value, channel: "mac-control", connection: connection.connection)
                #endif
                switch value {
                case .preparing: self.macPermissionWaiting = false
                case .ready:
                    guard self.macCandidates.contains(where: { $0 === connection }) else { return }
                    self.control = connection; self.macEndpoint = connection.connection.endpoint
                    self.macFallbackTask?.cancel(); self.macFallbackTask = nil
                    let losers = self.macCandidates.filter { $0 !== connection }
                    self.macCandidates.removeAll()
                    losers.forEach { $0.cancel() }
                    self.macPermissionWaiting = false
                    self.armMacConnectionTimeout(seconds: 10, token: token)
                    connection.send(["kind": .string("hello"), "version": .number(1), "channel": .string("control"), "deviceId": .string(self.deviceID)])
                case .waiting(let error):
                    self.macPermissionWaiting = MacServiceDiscovery.isPermissionDenied(error) || connection.connection.currentPath?.unsatisfiedReason == .localNetworkDenied
                case .failed(let error):
                    self.macCandidates.removeAll { $0 === connection }
                    if !self.macCandidates.isEmpty { return }
                    if MacServiceDiscovery.isPermissionDenied(error) || self.macPermissionWaiting || connection.connection.currentPath?.unsatisfiedReason == .localNetworkDenied {
                        self.localNetworkDenied()
                    } else { self.scheduleReconnect() }
                case .cancelled:
                    self.macCandidates.removeAll { $0 === connection }
                    if self.macCandidates.isEmpty { self.scheduleReconnect() }
                default: break
                }
            }
            connection.onMessage = { [weak self, weak connection] message in
                guard let self, let connection, self.generation == token, self.control === connection, self.macCandidates.isEmpty else { return }
                self.receive(message, channel: "control")
            }
        }
        control?.start(queue: .main)
        let delayed = Array(macCandidates.dropFirst())
        if !delayed.isEmpty {
            macFallbackTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, let self, self.generation == token, !self.macCandidates.isEmpty else { return }
                self.macFallbackTask = nil
                #if DEBUG
                ConnectionDiagnostics.record("starting-observed-interface-alternatives", channel: "mac-control")
                #endif
                for connection in delayed where self.macCandidates.contains(where: { $0 === connection }) {
                    connection.start(queue: .main)
                }
            }
        }
    }
    private func cancelMacCandidates() {
        macFallbackTask?.cancel(); macFallbackTask = nil
        macCandidates.forEach { $0.cancel() }; macCandidates.removeAll()
    }
    private func armMacConnectionTimeout(seconds: Double, token: UUID) {
        connectionTimeout?.cancel()
        connectionTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, self.generation == token, !self.connected else { return }
            #if DEBUG
            ConnectionDiagnostics.record("deadline-\(Int(seconds))s", channel: "mac-control", connection: self.control?.connection)
            #endif
            if self.macPermissionWaiting || self.control?.connection.currentPath?.unsatisfiedReason == .localNetworkDenied {
                self.localNetworkDenied()
                return
            }
            self.errorMessage = L10n.text("Nodus did not respond. Keep Presenter open on your computer, scan its current QR code, and check that Wi-Fi is enabled. Some networks block connections between devices.")
            self.scheduleReconnect()
        }
    }
    private func openMacAssets(pairing: Pairing, endpoint: NWEndpoint, token: UUID) {
        guard connected, assets == nil, assetsReconnectTask == nil else { return }
        // Control becomes usable before starting a second TLS connection/PDF.
        let parameters = PresenterTLS.parameters(key: pairing.key, identity: pairing.service)
        #if DEBUG
        ConnectionDiagnostics.excludeUSB(parameters)
        #endif
        // Reuse the effective peer endpoint of the authenticated control path.
        // Resolving the Bonjour name again can choose infrastructure Wi-Fi while
        // control already works over peer Wi-Fi. Preserve Network's IPv6 scope;
        // never construct an address or pin a private interface name ourselves.
        let peerEndpoint = control?.connection.currentPath?.remoteEndpoint ?? endpoint
        #if DEBUG
        ConnectionDiagnostics.record(peerEndpoint == endpoint ? "assets-service-endpoint" : "assets-control-path-endpoint", channel: "mac-assets")
        #endif
        let connection = FramedConnection(NWConnection(to: peerEndpoint, using: parameters))
        assets = connection
        assetsTimeout?.cancel()
        assetsTimeout = Task { [weak self, weak connection] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self, let connection, self.generation == token, !self.assetsReady else { return }
            self.recoverMacAssets(connection, token: token)
        }
        connection.onState = { [weak self, weak connection] value in
            guard let self, let connection, self.generation == token, self.assets === connection else { return }
            #if DEBUG
            ConnectionDiagnostics.record(value, channel: "mac-assets", connection: connection.connection)
            #endif
            switch value {
            case .ready:
                connection.send(["kind": .string("hello"), "version": .number(1), "channel": .string("assets"), "deviceId": .string(self.deviceID)])
                self.assetsTimeout?.cancel(); self.assetsTimeout = nil
                self.assetsReady = true; self.assetRetries = 0
                self.pendingImages.removeAll(); self.refreshVisibleImages()
            case .failed, .cancelled: self.recoverMacAssets(connection, token: token)
            default: break
            }
        }
        connection.onMessage = { [weak self, weak connection] message in
            guard let self, let connection, self.generation == token, self.assets === connection else { return }
            self.receive(message, channel: "assets")
        }
        connection.start(queue: .main)
    }
    private func recoverMacAssets(_ connection: FramedConnection, token: UUID) {
        guard generation == token, assets === connection, connected, foreground,
              let pairing, let endpoint = macEndpoint, assetsReconnectTask == nil else { return }
        assetsTimeout?.cancel(); assetsTimeout = nil
        connection.cancel(); assets = nil; assetsReady = false
        try? pdfFile?.close(); pdfFile = nil; downloadInFlight = false; pendingImages.removeAll()
        let delay = min(4, 1 << min(assetRetries, 2)); assetRetries += 1
        assetsReconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.generation == token else { return }
            self.assetsReconnectTask = nil
            self.openMacAssets(pairing: pairing, endpoint: endpoint, token: token)
        }
    }
    private func cancelAssetRecovery() {
        assetsReconnectTask?.cancel(); assetsReconnectTask = nil
        assetsTimeout?.cancel(); assetsTimeout = nil; assetRetries = 0
    }
    private func localNetworkDenied() {
        awaitingNetworkPermission = true; macPermissionWaiting = false
        serviceDiscovery.cancel()
        generation = UUID(); connected = false; status = L10n.text("Not connected")
        reconnectTask?.cancel(); reconnectTask = nil; connectionTimeout?.cancel(); connectionTimeout = nil
        cancelAssetRecovery(); cancelMacCandidates(); macEndpoint = nil
        control?.cancel(); assets?.cancel(); control = nil; assets = nil; assetsReady = false
        multipeer?.cancel(); multipeer = nil
        try? pdfFile?.close(); pdfFile = nil; downloadInFlight = false; pendingImages.removeAll()
        UIApplication.shared.isIdleTimerDisabled = false
        errorMessage = L10n.text("Local Network access is unavailable. Allow Nodus Presenter in Settings → Privacy & Security → Local Network, then return to the app or scan the QR code again.")
    }
    private func scheduleReconnect() {
        guard foreground, pairing != nil, reconnectTask == nil else { return }
        motionSender.cancel()
        serviceDiscovery.cancel()
        connectionTimeout?.cancel(); connectionTimeout = nil
        cancelAssetRecovery(); cancelMacCandidates(); macEndpoint = nil
        generation = UUID(); connected = false; status = L10n.text("Reconnecting to Nodus…")
        control?.cancel(); assets?.cancel(); control = nil; assets = nil; assetsReady = false
        multipeer?.cancel(); multipeer = nil
        lanCandidates.forEach { $0.cancel() }; lanCandidates.removeAll()
        try? pdfFile?.close(); pdfFile = nil; downloadInFlight = false; pendingImages.removeAll(); drawing = false
        UIApplication.shared.isIdleTimerDisabled = false
        let delay = min(8, 1 << min(retries, 3)); retries += 1
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            self.reconnectTask = nil; self.beginDiscovery()
        }
    }
    private func receive(_ message: Message, channel: String) {
        // A PDF transfer cannot hide an unresponsive control channel.
        if channel == "control" { lastReceipt = Date() }
        switch message["kind"]?.string {
        case "tool":
            // Multipeer streams positions without a full state echo. Local
            // feedback already painted the sender's position; other peers only
            // update the overlay, not the entire presentation UI.
            guard pairing?.usesMultipeer == true, channel == "control",
                  message["origin"]?.string != deviceID,
                  let action = message["action"]?.object, action["type"]?.string == "toolData" else { return }
            applyOverlay(action)
        case "update":
            guard channel == "control" else { return }
            guard let rawState = message["state"], let newState = try? PresenterState.decode(rawState) else { return }
            #if DEBUG
            ConnectionDiagnostics.record("valid-presenter-state", channel: "control", connection: control?.connection)
            #endif
            let oldSlide = state.currentSlide, oldID = state.pdfId
            state = newState
            connectionTimeout?.cancel(); connectionTimeout = nil
            connected = true; retries = 0; status = L10n.text("Connected to Nodus"); errorMessage = nil
            UIApplication.shared.isIdleTimerDisabled = true
            if let deck = message["deck"]?.object {
                deckName = deck["name"]?.string ?? L10n.text("Presentation")
                notes = deck["notes"]?.object?.compactMapValues(\.string) ?? [:]
                videos = deck["videos"]?.object ?? [:]
                let version = deck["assetVersion"]?.string ?? ""
                if assetVersion != version || oldID != state.pdfId {
                    try? pdfFile?.close(); pdfFile = nil; downloadInFlight = false
                    assetVersion = version; pdfDocument = nil; imageCache.removeAllObjects(); pendingImages.removeAll()
                }
            }
            if oldSlide != state.currentSlide { strokes = []; drawing = false }
            if let action = message["action"]?.object, message["origin"]?.string != deviceID { applyOverlay(action) }
            if let overlay = message["overlay"]?.arrayValue { strokes = []; for action in overlay.compactMap(\.object) { applyOverlay(action) } }
            if !localPreview { localSlide = state.currentSlide }
            if let pairing, pairing.lan == nil, !pairing.usesMultipeer, let endpoint = macEndpoint {
                openMacAssets(pairing: pairing, endpoint: endpoint, token: generation)
            }
            refreshVisibleImages()
        case "image":
            guard message["assetVersion"]?.string == assetVersion,
                  let page = message["page"]?.number, let encoded = message["data"]?.string,
                  let data = Data(base64Encoded: encoded), let image = UIImage(data: data) else { return }
            let key = imageKey(Int(page)); pendingImages.remove(key)
            imageCache.setObject(image, forKey: key as NSString, cost: Int(image.size.width * image.size.height * 4))
            imageRevision += 1
            #if DEBUG
            ConnectionDiagnostics.record("image-received", channel: "mac-assets", connection: assets?.connection)
            #endif
        case "volume": volume = message["value"]?.number ?? volume
        case "assetError":
            if message["page"] == nil { downloadInFlight = false }
            if let page = message["page"]?.number { pendingImages.remove(imageKey(Int(page))) }
            errorMessage = L10n.text("The presentation resource could not be loaded.")
        case "pdfBegin": beginPDF(message)
        case "pdfChunk":
            guard message["assetVersion"]?.string == downloadVersion,
                  message["offset"]?.number == Double(pdfOffset),
                  let text = message["data"]?.string, let data = Data(base64Encoded: text),
                  pdfOffset + data.count <= expectedPDFSize, let file = pdfFile else { return }
            do { try file.write(contentsOf: data); pdfOffset += data.count } catch { try? file.close(); pdfFile = nil }
        case "pdfEnd": finishPDF(message)
        case "ended": disconnect(); status = L10n.text("Presentation ended")
        default: break
        }
    }
    private func imageKey(_ page: Int) -> String { "\(assetVersion):\(page)" }
    func image(for page: Int, width: CGFloat = 1200) -> UIImage? {
        let baseKey = imageKey(page)
        let key = width < 600 ? "\(baseKey):thumb-\(Int(width))" : baseKey
        if let image = imageCache.object(forKey: key as NSString) { return image }
        if let document = pdfDocument, let pdfPage = document.page(at: page - 1) {
            let size = pdfPage.bounds(for: .mediaBox).size
            let image = pdfPage.thumbnail(of: CGSize(width: width, height: width * size.height / max(1, size.width)), for: .mediaBox)
            imageCache.setObject(image, forKey: key as NSString, cost: Int(image.size.width * image.size.height * 4)); return image
        }
        if width < 600, let full = imageCache.object(forKey: baseKey as NSString) {
            let size = CGSize(width: width, height: width * full.size.height / max(1, full.size.width))
            let format = UIGraphicsImageRendererFormat(); format.scale = 1
            let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in full.draw(in: CGRect(origin: .zero, size: size)) }
            imageCache.setObject(image, forKey: key as NSString, cost: Int(size.width * size.height * 4)); return image
        }
        return nil
    }
    func requestImage(_ page: Int) {
        guard page > 0, page <= state.totalSlides, !isDemo, assetsReady, image(for: page) == nil else { return }
        let key = imageKey(page)
        guard !pendingImages.contains(key) else { return }; pendingImages.insert(key)
        sendAssets(["kind": .string("image"), "page": .number(Double(page)), "width": .number(1280), "assetVersion": .string(assetVersion)])
    }
    private func refreshVisibleImages() {
        requestImage(displayedSlide); requestImage(min(state.totalSlides, displayedSlide + 1))
        guard assetsReady, !assetVersion.isEmpty, pdfDocument == nil, !downloadInFlight else { return }
        if pdfURL == nil || downloadVersion != assetVersion {
            let hash = SHA256.hash(data: Data(assetVersion.utf8)).map { String(format: "%02x", $0) }.joined()
            pdfURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("presenter-\(hash).partial")
            downloadVersion = assetVersion
        }
        let size = (try? pdfURL?.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        downloadInFlight = true
        sendAssets(["kind": .string("pdf"), "offset": .number(Double(size)), "assetVersion": .string(assetVersion)])
    }
    private func beginPDF(_ message: Message) {
        guard message["assetVersion"]?.string == assetVersion, let url = pdfURL else { return }
        guard let size = message["size"]?.number, size > 0, size <= 512 * 1024 * 1024, let offset = message["offset"]?.number, offset >= 0, offset <= size else { downloadInFlight = false; return }
        #if DEBUG
        ConnectionDiagnostics.record("pdf-begin", channel: "mac-assets", connection: assets?.connection)
        #endif
        expectedPDFSize = Int(size); pdfOffset = Int(offset)
        guard expectedPDFSize > 0, expectedPDFSize <= 512 * 1024 * 1024, pdfOffset >= 0, pdfOffset <= expectedPDFSize else { return }
        if pdfOffset == 0 { FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.protectionKey: FileProtectionType.completeUnlessOpen]) }
        pdfFile = try? FileHandle(forWritingTo: url); try? pdfFile?.seek(toOffset: UInt64(pdfOffset))
    }
    private func finishPDF(_ message: Message) {
        guard message["assetVersion"]?.string == assetVersion, pdfOffset == expectedPDFSize, let url = pdfURL,
              let expected = message["sha256"]?.string else { return }
        try? pdfFile?.close(); pdfFile = nil
        let version = assetVersion
        Task.detached { [self] in
            guard let file = try? FileHandle(forReadingFrom: url) else { return }
            defer { try? file.close() }
            var hasher = SHA256()
            while let chunk = try? file.read(upToCount: 65536), !chunk.isEmpty { hasher.update(data: chunk) }
            let actual = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            guard actual == expected else {
                try? FileManager.default.removeItem(at: url)
                await MainActor.run { if self.assetVersion == version { self.downloadInFlight = false; self.errorMessage = L10n.text("The download could not be verified. It will be retried.") } }; return
            }
            let final = url.deletingPathExtension().appendingPathExtension("pdf")
            try? FileManager.default.removeItem(at: final)
            do { try FileManager.default.moveItem(at: url, to: final) } catch { return }
            let document = PDFDocument(url: final)
            await MainActor.run {
                guard self.assetVersion == version else { return }
                self.pdfURL = final; self.downloadInFlight = false; self.pdfDocument = document; self.imageRevision += 1
                #if DEBUG
                ConnectionDiagnostics.record("pdf-verified", channel: "mac-assets", connection: self.assets?.connection)
                #endif
            }
        }
    }
    func send(_ action: Message) {
        if action["type"]?.string != "toolData" { motionSender.flush() }
        if localPreview && ["next", "prev", "navigate"].contains(action["type"]?.string ?? "") {
            let proposed = action["type"]?.string == "next" ? localSlide + 1 : action["type"]?.string == "prev" ? localSlide - 1 : Int(action["slide"]?.number ?? 1)
            localSlide = max(1, min(state.totalSlides, proposed)); requestImage(localSlide); return
        }
        guard canControl else { return }
        if isDemo {
            let oldSlide = state.currentSlide; state.applyDemo(action)
            if oldSlide != state.currentSlide { strokes = [] }
            applyOverlay(action); return
        }
        applyOverlay(action)
        sendControl(["kind": .string("action"), "commandId": .string(UUID().uuidString), "action": .object(action)])
    }
    func toggleTool(_ tool: Tool) {
        guard canControl else { return }
        // Global controls never cancel private reading. Only the book returns to the live slide.
        let disable = selectedTool == tool
        endActiveGesture()
        send(["type": .string("setTool"), "tool": disable ? .null : .string(tool.rawValue)])
    }
    func adjustSlideZoom(by delta: Double) {
        guard !localPreview else { return }
        setSlideZoom(scale: state.slideZoom.scale + delta, originX: state.slideZoom.originX, originY: state.slideZoom.originY)
    }
    func setSlideZoom(scale: Double, originX: Double, originY: Double) {
        guard !localPreview else { return }
        send(["type": .string("slideZoom"), "data": .object([
            "scale": .number(min(5, max(1, scale))),
            "originX": .number(min(100, max(0, originX))),
            "originY": .number(min(100, max(0, originY)))
        ])])
    }
    func setVolume(_ value: Double) {
        guard canControl, value.isFinite else { return }; volume = min(100, max(0, value.rounded()))
        if !isDemo { sendControl(["kind": .string("volume"), "value": .number(volume)]) }
    }
    func togglePreview() {
        endActiveGesture()
        localSlide = state.currentSlide; localPreview.toggle(); requestImage(displayedSlide)
    }
    func previewNextSlide() {
        let next = displayedSlide + 1
        guard next <= state.totalSlides else { return }
        endActiveGesture()
        localSlide = next; localPreview = true; requestImage(next)
    }
    func gesture(at point: CGPoint, ended: Bool = false) {
        guard !localPreview, let tool = selectedTool, canControl else { return }
        let pacedMotion = pairing?.usesMultipeer == true && !isDemo && tool != .draw
        if !pacedMotion && tool != .draw && !ended && Date().timeIntervalSince(lastToolSent) < 1.0 / 30 { return }
        lastToolSent = Date()
        var data: Message = ["tool": .string(tool.rawValue), "x": .number(min(100, max(0, point.x * 100))), "y": .number(min(100, max(0, point.y * 100)))]
        let size = state.toolSizes[tool.rawValue] ?? 15
        if tool == .draw {
            data["action"] = .string(ended ? "end" : drawing ? "move" : "start")
            data["color"] = .string(state.toolColor); data["lineWidth"] = .number(size)
            drawing = !ended
        } else if tool == .flashlight { data["r"] = .number(size) }
        else { data["size"] = .number(size) }
        let action: Message = ["type": .string("toolData"), "data": .object(data)]
        if pacedMotion {
            applyOverlay(action)
            motionSender.submit(action)
            if ended { motionSender.flush() }
        } else { send(action) }
    }
    func endActiveGesture() {
        motionSender.flush()
        if drawing { gesture(at: toolPosition, ended: true) }
    }
    private func applyOverlay(_ action: Message) {
        if action["type"]?.string == "clearDraw" { strokes = []; return }
        guard action["type"]?.string == "toolData", let data = action["data"]?.object else { return }
        let point = CGPoint(x: (data["x"]?.number ?? 50) / 100, y: (data["y"]?.number ?? 50) / 100)
        toolPosition = point
        guard data["tool"]?.string == "draw" else { return }
        switch data["action"]?.string {
        case "start": strokes.append(InkStroke(points: [point], color: data["color"]?.string ?? state.toolColor, width: data["lineWidth"]?.number ?? 4))
        case "move": if !strokes.isEmpty { strokes[strokes.count - 1].points.append(point) }
        case "clear": strokes = []
        default: break
        }
    }
}

extension JSONValue {
    var arrayValue: [JSONValue]? { if case .array(let value) = self { return value }; return nil }
}
