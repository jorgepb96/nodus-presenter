import Foundation
import Network
import Security
import CryptoKit

extension PresenterTLS {
    /// Windows/Linux use an ephemeral TLS certificate whose SHA-256 is carried in the QR.
    /// This is a separate path: the existing Mac TLS-PSK parameters remain unchanged.
    public static func lanParameters(fingerprint: Data) -> NWParameters {
        let tls = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(tls.securityProtocolOptions, .TLSv13)
        sec_protocol_options_set_verify_block(tls.securityProtocolOptions, { _, trust, complete in
            let reference = sec_trust_copy_ref(trust).takeRetainedValue()
            guard let certificate = SecTrustGetCertificateAtIndex(reference, 0) else { complete(false); return }
            let bytes = SecCertificateCopyData(certificate) as Data
            complete(Data(SHA256.hash(data: bytes)) == fingerprint)
        }, .main)
        let tcp = NWProtocolTCP.Options(); tcp.noDelay = true
        return NWParameters(tls: tls, tcp: tcp)
    }
}
