// Adapted from Apple's TicTacToe NWParameters+InitWithPasscode.swift.
// See ../APPLE-LICENSE.txt. The game framer is omitted: this probe uses fixed
// synthetic byte blocks, leaving discovery, TCP and TLS setup independent of Nodus.
import Foundation
import Network
import CryptoKit
import Security

enum PeerParameters {
    static var wirelessOnly: Bool {
        ProcessInfo.processInfo.arguments.contains("--wireless-only")
    }

    static func applyDiagnosticConstraints(_ parameters: NWParameters) {
        // Explicit diagnostic opt-in: leave USB available for developer launch
        // and log retrieval, but exclude it from the synthetic peer connection.
        if wirelessOnly { parameters.prohibitedInterfaceTypes = [.wiredEthernet] }
    }

    static func make(tls: Bool) -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 2
        let options: NWProtocolTLS.Options?
        if tls {
            let tlsOptions = NWProtocolTLS.Options()
            // Public test-only passcode: this tool never handles user documents.
            let key = SymmetricKey(data: Data("PeerLinkProbe-Local-Test".utf8))
            let code = HMAC<SHA256>.authenticationCode(for: Data("TicTacToe".utf8), using: key)
            let secret = code.withUnsafeBytes { DispatchData(bytes: $0) }
            let identity = Data("TicTacToe".utf8).withUnsafeBytes { DispatchData(bytes: $0) }
            sec_protocol_options_add_pre_shared_key(tlsOptions.securityProtocolOptions,
                                                    secret as __DispatchData, identity as __DispatchData)
            sec_protocol_options_append_tls_ciphersuite(tlsOptions.securityProtocolOptions,
                tls_ciphersuite_t(rawValue: TLS_PSK_WITH_AES_128_GCM_SHA256)!)
            options = tlsOptions
        } else {
            options = nil
        }
        let parameters = NWParameters(tls: options, tcp: tcp)
        parameters.includePeerToPeer = true
        applyDiagnosticConstraints(parameters)
        // No required interface or hand-written address. Normal runs impose no
        // interface exclusion; wireless-only is an explicit experiment above.
        return parameters
    }
}
