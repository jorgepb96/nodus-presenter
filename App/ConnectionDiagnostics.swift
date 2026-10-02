#if DEBUG
import Foundation
@preconcurrency import Network

/// Opt-in physical-device QA. Never prints the QR, key, service, peer name or addresses.
enum ConnectionDiagnostics {
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("--connection-diagnostics") }
    /// Explicit QA only: keep USB for Xcode, but prevent it carrying app data.
    /// Release builds never constrain interfaces.
    static func excludeUSB(_ parameters: NWParameters) {
        if enabled && ProcessInfo.processInfo.arguments.contains("--wireless-qa") {
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
            if path.status == .unsatisfied { fields.append("reason=\(path.unsatisfiedReason)") }
            fields.append("interfaces=\(path.availableInterfaces.map { "\($0.type)/\($0.name)" }.sorted().joined(separator: ","))")
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
