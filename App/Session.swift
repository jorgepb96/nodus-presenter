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
    private var discoveryTimeout: Task<Void, Never>?
    private var pairing: Pairing?
    private var browser: NWBrowser?
    private var control: FramedConnection?
    private var assets: FramedConnection?
    private var assetsReady = false
    private var generation = UUID()
    private var reconnectTask: Task<Void, Never>?
    private var retries = 0
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
    private var drawing = false

    init() {
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
        if let index = args.firstIndex(of: "--pair"), args.count > index + 1, let url = URL(string: args[index + 1]) { connect(url: url) }
        if args.contains("--demo") {
            enterDemo()
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

    func enterDemo() {
        disconnect()
        isDemo = true; connected = false; status = L10n.text("Demo · Not connected to Nodus")
        macName = L10n.text("Demo Mac"); deckName = L10n.text("Knowledge networks")
        pdfDocument = DemoDeck.make()
        state = PresenterState(); state.presenting = true; state.pdfId = "demo"
        state.totalSlides = pdfDocument?.pageCount ?? 8; state.currentSlide = 3; state.timerSeconds = 522
        state.toolColor = "#8b5cf6"
        notes = DemoDeck.notes; videos = ["4": .object(["url": .string("demo")])]
        localSlide = state.currentSlide; assetVersion = "demo"; imageRevision += 1
    }
    func connect(url: URL) {
        do {
            let newPairing = try Pairing(url: url)
            disconnect(); pairing = newPairing; macName = newPairing.name
            retries = 0; beginDiscovery()
        } catch { errorMessage = L10n.text("This QR code is not a Nodus Presenter app session. Choose App iPhone–iPad in Nodus.") }
    }
    func disconnect() {
        generation = UUID(); reconnectTask?.cancel(); reconnectTask = nil; discoveryTimeout?.cancel(); discoveryTimeout = nil
        browser?.cancel(); browser = nil; control?.cancel(); assets?.cancel(); control = nil; assets = nil
        assetsReady = false; connected = false; isDemo = false; pairing = nil
        state = PresenterState(); deckName = ""; notes = [:]; videos = [:]; pdfDocument = nil
        imageCache.removeAllObjects(); pendingImages.removeAll(); strokes = []
        try? pdfFile?.close(); pdfFile = nil; pdfURL = nil; pdfOffset = 0; downloadVersion = ""; downloadInFlight = false
        localPreview = false; showTools = false; showSlides = false; status = L10n.text("Not connected")
        UIApplication.shared.isIdleTimerDisabled = false
    }
    func sceneChanged(_ phase: ScenePhase) {
        UIApplication.shared.isIdleTimerDisabled = phase == .active && (connected || isDemo)
        foreground = phase != .background
        if phase == .background, pairing != nil {
            generation = UUID(); connected = false; status = L10n.text("Not connected · App in background")
            reconnectTask?.cancel(); reconnectTask = nil; discoveryTimeout?.cancel(); discoveryTimeout = nil
            browser?.cancel(); browser = nil; control?.cancel(); control = nil; assets?.cancel(); assets = nil; assetsReady = false
            try? pdfFile?.close(); pdfFile = nil; downloadInFlight = false
        }
        if phase == .active, pairing != nil, !connected, reconnectTask == nil { beginDiscovery() }
    }
    private func tick() {
        if isDemo { if state.timerRunning { state.timerSeconds += 1 }; return }
        guard connected else { return }
        if Date().timeIntervalSince(lastReceipt) > 12 { scheduleReconnect(); return }
        control?.send(["kind": .string("ping")]); refreshVisibleImages()
    }
    private func beginDiscovery() {
        guard let pairing else { return }
        let token = UUID(); generation = token
        connected = false; status = retries == 0 ? L10n.text("Looking for Nodus…") : L10n.text("Reconnecting to Nodus…")
        let parameters = NWParameters.tcp; parameters.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: Pairing.serviceType, domain: nil), using: parameters)
        self.browser = browser
        browser.stateUpdateHandler = { [weak self] value in
            Task { @MainActor in
            guard let self, self.generation == token else { return }
            if case .failed = value {
                self.errorMessage = L10n.text("Unable to find Nodus. Check the local network permission and that Wi-Fi is enabled.")
                self.scheduleReconnect()
            }
            }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
            guard let self, self.generation == token else { return }
            for result in results {
                if case .service(let name, _, _, _) = result.endpoint, name == pairing.service {
                    self.browser?.cancel(); self.browser = nil
                    self.open(endpoint: result.endpoint, pairing: pairing, token: token); return
                }
            }
            }
        }
        browser.start(queue: .main)
        discoveryTimeout?.cancel()
        discoveryTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(12))
            guard !Task.isCancelled, let self, self.generation == token, !self.connected else { return }
            self.scheduleReconnect()
        }
    }
    private func open(endpoint: NWEndpoint, pairing: Pairing, token: UUID) {
        status = L10n.text("Connecting to Nodus…")
        for channel in ["control", "assets"] {
            let connection = FramedConnection(NWConnection(to: endpoint, using: PresenterTLS.parameters(key: pairing.key, identity: pairing.service)))
            if channel == "control" { control = connection } else { assets = connection }
            connection.onState = { [weak self, weak connection] value in
                guard let self, self.generation == token else { return }
                switch value {
                case .ready:
                    connection?.send(["kind": .string("hello"), "version": .number(1), "channel": .string(channel), "deviceId": .string(self.deviceID)])
                    if channel == "assets" { self.assetsReady = true; self.pendingImages.removeAll(); self.refreshVisibleImages() }
                case .failed, .cancelled: self.scheduleReconnect()
                default: break
                }
            }
            connection.onMessage = { [weak self] message in
                guard let self, self.generation == token else { return }; self.receive(message, channel: channel)
            }
            connection.start(queue: .main)
        }
    }
    private func scheduleReconnect() {
        guard foreground, pairing != nil, reconnectTask == nil else { return }
        discoveryTimeout?.cancel(); discoveryTimeout = nil
        generation = UUID(); connected = false; status = L10n.text("Reconnecting to Nodus…")
        browser?.cancel(); browser = nil; control?.cancel(); assets?.cancel(); control = nil; assets = nil; assetsReady = false
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
        case "update":
            guard channel == "control" else { return }
            guard let rawState = message["state"], let newState = try? PresenterState.decode(rawState) else { return }
            let oldSlide = state.currentSlide, oldID = state.pdfId
            state = newState
            discoveryTimeout?.cancel(); discoveryTimeout = nil
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
            refreshVisibleImages()
        case "image":
            guard message["assetVersion"]?.string == assetVersion,
                  let page = message["page"]?.number, let encoded = message["data"]?.string,
                  let data = Data(base64Encoded: encoded), let image = UIImage(data: data) else { return }
            let key = imageKey(Int(page)); pendingImages.remove(key)
            imageCache.setObject(image, forKey: key as NSString, cost: Int(image.size.width * image.size.height * 4))
            imageRevision += 1
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
        assets?.send(["kind": .string("image"), "page": .number(Double(page)), "width": .number(1280), "assetVersion": .string(assetVersion)])
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
        assets?.send(["kind": .string("pdf"), "offset": .number(Double(size)), "assetVersion": .string(assetVersion)])
    }
    private func beginPDF(_ message: Message) {
        guard message["assetVersion"]?.string == assetVersion, let url = pdfURL else { return }
        guard let size = message["size"]?.number, size > 0, size <= 512 * 1024 * 1024, let offset = message["offset"]?.number, offset >= 0, offset <= size else { downloadInFlight = false; return }
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
            }
        }
    }
    func send(_ action: Message) {
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
        control?.send(["kind": .string("action"), "commandId": .string(UUID().uuidString), "action": .object(action)])
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
        guard canControl else { return }; volume = value
        if !isDemo { control?.send(["kind": .string("volume"), "value": .number(value)]) }
    }
    func togglePreview() {
        localSlide = state.currentSlide; localPreview.toggle(); requestImage(displayedSlide)
    }
    func gesture(at point: CGPoint, ended: Bool = false) {
        guard !localPreview, let tool = selectedTool, canControl else { return }
        if tool != .draw && !ended && Date().timeIntervalSince(lastToolSent) < 1.0 / 30 { return }
        lastToolSent = Date()
        var data: Message = ["tool": .string(tool.rawValue), "x": .number(min(100, max(0, point.x * 100))), "y": .number(min(100, max(0, point.y * 100)))]
        let size = state.toolSizes[tool.rawValue] ?? 15
        if tool == .draw {
            data["action"] = .string(ended ? "end" : drawing ? "move" : "start")
            data["color"] = .string(state.toolColor); data["lineWidth"] = .number(size)
            drawing = !ended
        } else if tool == .flashlight { data["r"] = .number(size) }
        else { data["size"] = .number(size) }
        send(["type": .string("toolData"), "data": .object(data)])
    }
    func endActiveGesture() {
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
