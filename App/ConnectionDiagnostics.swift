#if DEBUG
import Foundation
@preconcurrency import Network

/// Opt-in physical-device QA. Never prints the QR, key, service, peer name or addresses.
enum ConnectionDiagnostics {
    private static var defaultPathMonitor: NWPathMonitor?

    static func startPathMonitoring() {
        guard enabled, defaultPathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        defaultPathMonitor = monitor
        monitor.pathUpdateHandler = { path in
            record("default-path=\(path.status) wifi=\(path.usesInterfaceType(.wifi)) cellular=\(path.usesInterfaceType(.cellular)) wired=\(path.usesInterfaceType(.wiredEthernet)) ipv4=\(path.supportsIPv4) dns=\(path.supportsDNS)", channel: "app")
        }
        monitor.start(queue: .main)
    }
    static var enabled: Bool {
        #if PRESENTER_WIRELESS_QA
        return true
        #else
        return ProcessInfo.processInfo.arguments.contains("--connection-diagnostics")
        #endif
    }
    static var wirelessQA: Bool {
        #if PRESENTER_WIRELESS_QA
        return true
        #else
        return enabled && ProcessInfo.processInfo.arguments.contains("--wireless-qa")
        #endif
    }
    /// Controlled comparison only: a cable-learned Bonjour result must not end
    /// wireless discovery before a Wi-Fi advertisement is observed.
    static var wifiDiscovery: Bool {
        enabled && ProcessInfo.processInfo.arguments.contains("--wifi-discovery")
    }

    /// Explicit comparison of only the interface reported by Bonjour.
    static var scopeDiscovery: Bool {
        enabled && (ProcessInfo.processInfo.arguments.contains("--scope-discovery") || peerDiscovery)
    }

    /// The local candidate keeps Network's normal choice first and adds only
    /// observed interfaces as delayed alternatives. Release excludes this.
    static var scopedFallback: Bool {
        #if PRESENTER_WIRELESS_QA
        return !ProcessInfo.processInfo.arguments.contains("--unscoped-discovery") && !scopeDiscovery
        #else
        return false
        #endif
    }

    static var peerDiscovery: Bool {
        enabled && ProcessInfo.processInfo.arguments.contains("--peer-discovery")
    }

    /// Identify a separately discovered Wi-Fi interface using public interface
    /// identities, without assuming any private peer-interface name.
    static func isSeparateWiFi(_ interface: NWInterface) -> Bool {
        guard interface.type == .wifi,
              let path = defaultPathMonitor?.currentPath, path.status == .satisfied else { return false }
        let defaults = path.availableInterfaces.filter { $0.type == .wifi }.map(\.index)
        return !defaults.contains(interface.index)
    }

    static func recordDiscovery(_ result: NWBrowser.Result) {
        guard enabled else { return }
        let interfaces = result.interfaces.map { "\($0.type)/\($0.name)" }.sorted().joined(separator: ",")
        let scope = result.endpoint.interface.map { "\($0.type)/\($0.name)" } ?? "unscoped"
        record("result interfaces=\(interfaces) endpointScope=\(scope)", channel: "mac-discovery")
    }
    /// Explicit QA only: keep USB for Xcode, but prevent it carrying app data.
    /// Release builds never constrain interfaces.
    static func excludeUSB(_ parameters: NWParameters) {
        if wirelessQA {
            parameters.prohibitedInterfaceTypes = [.wiredEthernet]
        }
    }

    static func record(_ event: String, channel: String, connection: NWConnection? = nil, error: NWError? = nil) {
        guard enabled else { return }
        var fields = ["PresenterConnection", channel, event]
        if let error {
            switch error {
            case .dns(let code): fields.append("dns=\(code)")
            case .posix(let code): fields.append("posix=\(code.rawValue)")
            case .tls(let code): fields.append("tls=\(code)")
            default: fields.append("network-error")
            }
        }
        if let path = connection?.currentPath {
            fields.append("path=\(path.status)")
            let types: [NWInterface.InterfaceType] = [.wifi, .wiredEthernet, .cellular, .loopback, .other]
            fields.append("usesTypes=\(types.filter { path.usesInterfaceType($0) }.map { String(describing: $0) }.joined(separator: ","))")
            if path.status == .unsatisfied { fields.append("reason=\(path.unsatisfiedReason)") }
            fields.append("availableInterfaces=\(path.availableInterfaces.map { "\($0.type)/\($0.name)" }.sorted().joined(separator: ","))")
            let remoteScope = path.remoteEndpoint?.interface.map { "\($0.type)/\($0.name)" } ?? "unscoped"
            fields.append("remoteScope=\(remoteScope)")
        }
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(fields.joined(separator: " "))\n"
        print(line, terminator: "")
        // Retain the radio failure while USB/Xcode is disconnected. DEBUG-only,
        // opt-in, bounded, on-device storage; no background upload or session data.
        let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("presenter-connection-diagnostics.log")
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.protectionKey: FileProtectionType.completeUnlessOpen])
        }
        guard let file = try? FileHandle(forWritingTo: url) else { return }
        defer { try? file.close() }
        if ((try? file.seekToEnd()) ?? 0) > 256 * 1024 { try? file.truncate(atOffset: 0); try? file.seek(toOffset: 0) }
        if let data = line.data(using: .utf8) { try? file.write(contentsOf: data) }
    }

    static func record(_ state: NWConnection.State, channel: String, connection: NWConnection) {
        switch state {
        case .setup: record("setup", channel: channel, connection: connection)
        case .preparing: record("preparing", channel: channel, connection: connection)
        case .waiting(let error): record("waiting", channel: channel, connection: connection, error: error)
        case .ready: record("tls-ready", channel: channel, connection: connection)
        case .failed(let error): record("failed", channel: channel, connection: connection, error: error)
        case .cancelled: record("cancelled", channel: channel, connection: connection)
        @unknown default: record("unknown-state", channel: channel, connection: connection)
        }
    }
}
#endif
