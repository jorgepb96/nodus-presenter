import Foundation
import Network
import Combine

final class ProbeModel: ObservableObject {
    @Published var status = "Preparado"
    @Published var path = "Sin conexión"
    @Published var events: [String] = []
    @Published var roundTrips = 0
    @Published var bytesReceived = 0
    @Published var running = false
    @Published var connected = false
    @Published var tls = true
    @Published var hosting: Bool = {
        #if os(macOS)
        return true
        #else
        return false
        #endif
    }()
    @Published var phase = "Sin iniciar"

    private var browser: NWBrowser?
    private var listener: NWListener?
    private var connection: NWConnection?
    private var defaultPathMonitor: NWPathMonitor?
    private var generation = UUID()
    private var timer: Timer?
    private var deadline: DispatchWorkItem?
    private var buffer = Data()
    private var pending: Data?
    private var sequence: UInt8 = 0
    private var sentAt = Date.distantPast
    private var startedAt = Date()
    private let blockSize = 1024
    private var serviceType: String { tls ? "_peerprobe-tls._tcp" : "_peerprobe-tcp._tcp" }
    // A new, exact service identity for the next controlled mixed-network run.
    // Do not start an infrastructure baseline first: that would populate the
    // same resolver cache this experiment is intended to distinguish.
    private let serviceName: String = {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--service-id"),
           arguments.indices.contains(index + 1) {
            let token = arguments[index + 1]
            if token.count == 32 && token.allSatisfy({ $0.isHexDigit }) {
                return "PeerLinkProbe-" + token
            }
        }
        return "PeerLinkProbe-Round2"
    }()
    let logURL: URL

    init() {
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        logURL = directory.appendingPathComponent("peer-link-probe.log")
        log("launch probe-revision=2; fresh service identity; independent Apple-sample-based probe; no personal payloads")
        log("diagnostic-wireless-only=\(PeerParameters.wirelessOnly)")
        let monitor = NWPathMonitor()
        defaultPathMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            self?.log("default-path status=\(path.status) wifi=\(path.usesInterfaceType(.wifi)) cellular=\(path.usesInterfaceType(.cellular)) wired=\(path.usesInterfaceType(.wiredEthernet)) ipv4=\(path.supportsIPv4) dns=\(path.supportsDNS)")
        }
        monitor.start(queue: .main)
    }

    func log(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)"
        events.append(line)
        if events.count > 70 { events.removeFirst(events.count - 70) }
        let data = Data((line + "\n").utf8)
        if let handle = try? FileHandle(forWritingTo: logURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else { try? data.write(to: logURL) }
    }

    func stop() {
        generation = UUID()
        deadline?.cancel(); deadline = nil
        timer?.invalidate(); timer = nil
        browser?.cancel(); browser = nil
        listener?.cancel(); listener = nil
        connection?.cancel(); connection = nil
        running = false; connected = false
        buffer.removeAll(); pending = nil
        status = "Detenido"
    }

    func start(_ declaredPhase: String) {
        stop()
        roundTrips = 0; bytesReceived = 0; sequence = 0
        path = "Sin conexión"; phase = declaredPhase; startedAt = Date()
        running = true
        let id = generation
        log("start phase=\(declaredPhase) role=\(hosting ? "server" : "client") transport=\(tls ? "TLS" : "TCP")")
        if hosting { startListener(id) } else { startBrowser(id) }
    }

    private func startListener(_ id: UUID) {
        do {
            let listener = try NWListener(using: PeerParameters.make(tls: tls))
            listener.service = .init(name: serviceName, type: serviceType)
            self.listener = listener
            status = "Iniciando servidor"
            listener.stateUpdateHandler = { [weak self] state in
                guard let self, self.generation == id else { return }
                switch state {
                case .ready: self.status = "Servidor listo · esperando iPhone"; self.log("listener-ready")
                case .waiting(let error): self.status = "Servidor esperando: \(error)"; self.log("listener-waiting \(error)")
                case .failed(let error): self.status = "Error del servidor: \(error)"; self.log("listener-failed \(error)")
                default: break
                }
            }
            listener.newConnectionHandler = { [weak self] incoming in
                guard let self, self.generation == id else { incoming.cancel(); return }
                self.connection?.cancel()
                self.buffer.removeAll(); self.pending = nil
                self.roundTrips = 0; self.bytesReceived = 0
                self.log("incoming-connection")
                self.attach(incoming, id: id)
            }
            listener.start(queue: .main)
        } catch { status = "Error: \(error)"; log("listener-creation-failed \(error)") }
    }

    private func startBrowser(_ id: UUID) {
        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        PeerParameters.applyDiagnosticConstraints(parameters)
        let browser = NWBrowser(for: .bonjour(type: serviceType, domain: nil), using: parameters)
        self.browser = browser
        status = "1 · Buscando el Mac"
        browser.stateUpdateHandler = { [weak self, weak browser] state in
            guard let self, self.generation == id, self.browser === browser else { return }
            switch state {
            case .ready: self.log("browser-ready")
            case .waiting(let error): self.log("browser-waiting \(error)"); self.status = "Búsqueda esperando: \(error)"
            case .failed(let error): self.log("browser-failed \(error)"); self.status = "Error de búsqueda: \(error)"
            default: break
            }
        }
        browser.browseResultsChangedHandler = { [weak self, weak browser] results, _ in
            guard let self, self.generation == id, self.browser === browser else { return }
            guard let match = results.first(where: {
                if case .service(let name, _, _, _) = $0.endpoint { return name == self.serviceName }
                return false
            }) else { return }
            let interfaces = match.interfaces.map { "\($0.type):\($0.name)" }.sorted().joined(separator: ",")
            let scope = match.endpoint.interface.map { "\($0.type):\($0.name)" } ?? "unscoped"
            self.log("discovered interfaces=\(interfaces) endpoint-scope=\(scope) matching-results=\(results.filter { $0.endpoint == match.endpoint }.count)")
            // In the USB-attached diagnostic only, avoid consuming a service
            // first discovered solely over the cable. Connection constraints
            // do not prove that the Bonjour result was learned wirelessly.
            // This checks the public interface type, never a private name,
            // and leaves the selected endpoint and normal manual runs intact.
            if ProcessInfo.processInfo.arguments.contains("--wifi-discovery"),
               !match.interfaces.contains(where: { $0.type == .wifi }) {
                self.log("diagnostic-discovery-deferred: no Wi-Fi discovery interface yet")
                return
            }
            // TN3213: stop browsing before connecting to the selected endpoint.
            browser?.cancel(); self.browser = nil
            self.deadline?.cancel()
            self.attach(NWConnection(to: match.endpoint, using: PeerParameters.make(tls: self.tls)), id: id)
        }
        browser.start(queue: .main)
        setDeadline(id, seconds: 30, message: "No se ha descubierto el Mac en 30 s")
    }

    private func attach(_ conn: NWConnection, id: UUID) {
        connection = conn; connected = false
        let scope = conn.endpoint.interface.map { "\($0.type):\($0.name)" } ?? "unscoped"
        log("connection-endpoint-scope=\(scope)")
        status = tls ? "2 · Estableciendo TLS" : "2 · Conectando TCP"
        conn.stateUpdateHandler = { [weak self, weak conn] state in
            guard let self, let conn, self.generation == id, self.connection === conn else { return }
            switch state {
            case .ready:
                self.deadline?.cancel(); self.deadline = nil
                if PeerParameters.wirelessOnly,
                   conn.currentPath?.usesInterfaceType(.wiredEthernet) == true {
                    self.log("invalid-wireless-test: wired path selected")
                    self.stop(); self.status = "Prueba inválida: se ha seleccionado el cable"
                    return
                }
                self.connected = true; self.status = "3 · Conectado · comprobando datos"
                self.log("connection-ready elapsed=\(Int(Date().timeIntervalSince(self.startedAt)))s")
                if let path = conn.currentPath { self.report(path) }
                self.receive(conn, id: id)
                if !self.hosting { self.startPings(conn, id: id) }
            case .waiting(let error): self.log("connection-waiting \(error)"); self.status = "Conexión esperando: \(error)"
            case .failed(let error):
                self.connected = false; self.timer?.invalidate()
                self.log("connection-failed \(error)"); self.status = "Fallo: \(error)"
            case .cancelled: self.connected = false; self.log("connection-cancelled")
            case .preparing: self.log("connection-preparing")
            default: break
            }
        }
        conn.pathUpdateHandler = { [weak self, weak conn] path in
            guard let self, self.generation == id, self.connection === conn else { return }
            self.report(path)
        }
        conn.viabilityUpdateHandler = { [weak self, weak conn] viable in
            guard let self, self.generation == id, self.connection === conn else { return }
            self.log("viability=\(viable)")
            if !viable, self.connected { self.status = "Enlace sin viabilidad" }
        }
        conn.start(queue: .main)
        if !hosting { setDeadline(id, seconds: 30, message: "Mac descubierto, pero la conexión no termina en 30 s") }
    }

    private func setDeadline(_ id: UUID, seconds: Double, message: String) {
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generation == id else { return }
            self.log("deadline: \(message)")
            self.stop()
            self.status = message
        }
        deadline = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func report(_ networkPath: NWPath) {
        let interfaces = networkPath.availableInterfaces.map { "\($0.type):\($0.name)" }.sorted().joined(separator: ", ")
        let wired = networkPath.usesInterfaceType(.wiredEthernet)
        path = "\(networkPath.status) · \(interfaces)\(wired ? " · ⚠ Cable/ethernet" : "")"
        log("path=\(path) wifi=\(networkPath.usesInterfaceType(.wifi)) ipv6=\(networkPath.supportsIPv6)")
    }

    private func startPings(_ conn: NWConnection, id: UUID) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self, weak conn] _ in
            guard let self, let conn, self.generation == id, self.connection === conn else { return }
            if self.pending != nil {
                let seconds = Int(Date().timeIntervalSince(self.sentAt))
                if seconds >= 5 { self.status = "Sin respuesta desde hace \(seconds) s" }
                if seconds >= 15 {
                    self.log("echo-timeout 15s")
                    self.stop(); self.status = "La conexión dejó de responder durante 15 s"
                }
                return
            }
            self.sequence = (self.sequence &+ 1) % 251
            let data = Data(repeating: self.sequence, count: self.blockSize)
            self.pending = data; self.sentAt = Date()
            self.send(data, over: conn, id: id)
        }
    }

    private func send(_ data: Data, over conn: NWConnection, id: UUID) {
        conn.send(content: data, completion: .contentProcessed { [weak self, weak conn] error in
            guard let self, self.generation == id, self.connection === conn else { return }
            if let error { self.log("send-error \(error)") }
        })
    }

    private func receive(_ conn: NWConnection, id: UUID) {
        conn.receive(minimumIncompleteLength: 1, maximumLength: blockSize) { [weak self, weak conn] data, _, complete, error in
            guard let self, let conn, self.generation == id, self.connection === conn else { return }
            if let data {
                self.buffer.append(data)
                while self.buffer.count >= self.blockSize {
                    let block = Data(self.buffer.prefix(self.blockSize))
                    self.buffer.removeFirst(self.blockSize)
                    self.bytesReceived += block.count
                    if self.hosting {
                        self.send(block, over: conn, id: id)
                    } else {
                        guard self.pending == block else {
                            self.log("echo-validation-failed"); self.stop(); self.status = "Datos de respuesta incorrectos"; return
                        }
                        self.pending = nil
                    }
                    self.roundTrips += 1
                    self.status = self.hosting ? "Datos recibidos y devueltos" : "Datos verificados ✓"
                    if self.roundTrips == 1 || self.roundTrips % 5 == 0 {
                        self.log("\(self.hosting ? "echoed" : "verified") blocks=\(self.roundTrips) bytes=\(self.bytesReceived)")
                    }
                }
            }
            if let error {
                self.connected = false; self.timer?.invalidate()
                self.log("receive-error \(error)"); self.status = "Recepción interrumpida: \(error)"
            } else if complete {
                self.connected = false; self.timer?.invalidate()
                self.log("peer-closed"); self.status = "El otro dispositivo cerró la conexión"
            } else { self.receive(conn, id: id) }
        }
    }
}
