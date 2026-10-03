import Foundation
@preconcurrency import MultipeerConnectivity
import PresenterCore

/// Explicit QR-selected experiment, using the framework documented for Keynote
/// Remote. Green status still requires authenticated Presenter state, not merely
/// MCSessionState.connected. No shared-router or Internet preflight is used.
@MainActor final class MultipeerPresenterConnection: NSObject {
    var onReady: (() -> Void)?
    var onConnecting: (() -> Void)?
    var onMessage: ((Message, String) -> Void)?
    var onFailure: ((Error?) -> Void)?
    private let pairing: Pairing
    private let session: MCSession
    private var browser: MCNearbyServiceBrowser?
    private var remote: MCPeerID?
    private var codec: PeerMessageCodec?
    private var stopped = false
    private let nonce = UUID().uuidString

    init(pairing: Pairing) {
        self.pairing = pairing
        let local = MCPeerID(displayName: "phone-" + UUID().uuidString.lowercased())
        session = MCSession(peer: local, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        session.delegate = self
    }
    func start() {
        guard !stopped, browser == nil else { return }
        let browser = MCNearbyServiceBrowser(peer: session.myPeerID, serviceType: PeerMessageCodec.serviceType)
        self.browser = browser; browser.delegate = self
        browser.startBrowsingForPeers()
        record("browse-start")
    }
    func send(_ message: Message, channel: PeerChannel) {
        guard !stopped, let remote, let codec, session.connectedPeers.contains(remote) else { return }
        do {
            let packet = try codec.seal(message, channel: channel)
            try session.send(packet.data, toPeers: [remote], with: .reliable)
        } catch { fail(error) }
    }
    func cancel() {
        guard !stopped else { return }
        stopped = true
        onReady = nil; onConnecting = nil; onMessage = nil; onFailure = nil
        browser?.delegate = nil; browser?.stopBrowsingForPeers(); browser = nil
        session.delegate = nil; session.disconnect(); remote = nil; codec = nil
    }
    private func fail(_ error: Error?) {
        guard !stopped else { return }
        record("failed", error: error)
        let callback = onFailure
        cancel(); callback?(error)
    }
    private func found(_ peer: MCPeerID, info: [String: String]?, browser: MCNearbyServiceBrowser) {
        guard !stopped, self.browser === browser, remote == nil,
              info?["session"] == pairing.service, peer.displayName == pairing.service else { return }
        do {
            let invitation = try PeerMessageCodec(key: pairing.key, service: pairing.service, nonce: "invitation", direction: .toMac)
            let packet = try invitation.seal(["kind": .string("invite"), "nonce": .string(nonce),
                                             "peer": .string(session.myPeerID.displayName)], channel: .invitation)
            codec = try PeerMessageCodec(key: pairing.key, service: pairing.service, nonce: nonce, direction: .toMac)
            remote = peer
            record("peer-found")
            onConnecting?()
            browser.invitePeer(peer, to: session, withContext: packet.data, timeout: 30)
        } catch { fail(error) }
    }
    private func changed(_ peer: MCPeerID, state: MCSessionState, session: MCSession) {
        guard !stopped, self.session === session, peer == remote else { return }
        switch state {
        case .connecting: record("connecting")
        case .connected:
            record("connected-awaiting-presenter-state")
            browser?.delegate = nil; browser?.stopBrowsingForPeers(); browser = nil
            onReady?()
        case .notConnected: fail(nil)
        @unknown default: fail(nil)
        }
    }
    private func received(_ data: Data, peer: MCPeerID, session: MCSession) {
        guard !stopped, self.session === session, peer == remote, let codec else { return }
        do {
            let packet = try codec.open(data)
            switch packet.channel {
            case .control: onMessage?(packet.message, "control")
            case .assets:
                onMessage?(packet.message, "assets")
                // A PDF block is acknowledged after the normal app receiver has
                // consumed it. The host keeps at most one block in flight.
                send(["sequence": .number(Double(packet.sequence))], channel: .assetAcknowledgement)
            default: throw ProtocolError.invalidFrame
            }
        } catch { fail(error) }
    }
    private func record(_ event: String, error: Error? = nil) {
        #if DEBUG
        let code = error.map { "-error-\(($0 as NSError).code)" } ?? ""
        ConnectionDiagnostics.record(event + code, channel: "multipeer")
        #endif
    }
}

extension MultipeerPresenterConnection: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async { [weak self] in self?.found(peerID, info: info, browser: browser) }
    }
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {}
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.browser === browser else { return }; self.fail(error)
        }
    }
}
extension MultipeerPresenterConnection: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in self?.changed(peerID, state: state, session: session) }
    }
    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Keep reliable channel packets in delegate delivery order. Unstructured
        // Tasks do not promise FIFO scheduling on the main actor.
        DispatchQueue.main.async { [weak self] in self?.received(data, peer: peerID, session: session) }
    }
    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
