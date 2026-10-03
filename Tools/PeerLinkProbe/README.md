# Independent physical peer-link probe

Standalone iOS and native macOS apps; no PresenterCore, Electron, QR, document,
asset download or Nodus lifecycle code. The installed Nodus apps are untouched.

Based on Apple's [Building a custom peer-to-peer protocol](https://developer.apple.com/documentation/network/building-a-custom-peer-to-peer-protocol)
TicTacToe sample. `PeerParameters.swift` preserves its TLS PSK derivation/cipher,
TCP keepalive and `includePeerToPeer`. Bonjour uses default browser parameters,
peer opt-in and the returned endpoint. Browsing stops before connection per
[TN3213](https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework).
The game framer is replaced with fixed 1024-byte synthetic echo blocks.
This is an adaptation, not an unmodified Apple sample or Apple diagnostic app.
Apple's license is in APPLE-LICENSE.txt.

Build with `xcodegen generate`, then build PeerLinkMac / PeerLinkPhone with Xcode.
The separate bundle IDs require their own Local Network permission on both devices.
The Mac target is a signed native app, not an unsigned command-line helper.

## Physical procedure

1. Keep default TLS enabled on both sides. Start the Mac server and grant Local
   Network/incoming connection access if prompted. iPhone is the client.
2. Baseline on the same infrastructure network: tap **1. Probar con red**.
   Confirm discovery, TLS readiness and incrementing verified echoes. An attached
   USB cable can provide a wired path: record it, never call that a Wi-Fi result.
3. Disconnect USB and disassociate both devices from infrastructure without
   powering Wi-Fi off. Personal Hotspot must not be providing a network.
   After the network change, tap **2. Nueva prueba sin red** on iPhone.
   This closes the old socket and performs new discovery/TLS; no automatic retries
   can turn a later rejoin into a purported offline pass.
4. After 30 seconds record whether discovery or TLS timed out, or whether verified
   echo counts increased. Keep app open. Restore network/USB to retrieve local logs.
5. Only if needed, stop both apps and disable TLS on **both** to distinguish basic
   TCP establishment from a TLS handshake problem. A separate service type prevents
   cross-mode pairing. This is a secondary experiment, not the primary baseline.

Interface descriptions and declared test phase are evidence, not proof of physical
network association state. Record the owner's confirmation separately. Successful
AWDL-labelled traffic while associated must never be claimed as router-free success.

Logs live in each app's Caches/peer-link-probe.log, contain timestamps, phases,
errors, interface descriptions and synthetic counters, and are not uploaded.
The test PSK is public; this tool carries no personal data or production credentials.
Do not publish this app to TestFlight or App Store.

## Second controlled run

Revision 2 uses a new exact service name on both sides. The next comparison must
start directly in the mixed condition (Mac unassociated, iPhone associated), with
USB removed. Do not launch this revision on the shared infrastructure first. This
reduces reuse of records learned during an earlier shared-network baseline; it is
not proof that every DNS cache is empty. Keep the VPN condition explicit and held
constant rather than changing Wi-Fi and VPN together. Starting the Mac listener
again does not generate another new identity in manual mode. Automated runs pass
the same fresh 32-character hexadecimal `--service-id` to both processes. This
synthetic ID is not written to diagnostic logs and prevents an aborted run that
rejoined a router from populating the next run's exact-service discovery cache.

Additional diagnostics record the discovered endpoint's optional interface scope
and the connection endpoint's scope, without service names or addresses. The
returned endpoint is still used unchanged; no interface is forced or excluded.
This is an investigation of the earlier `en0` versus peer-interface discovery
difference, not a confirmed fix or an update to the production Nodus apps.

The owner subsequently requested automatic execution with the unlocked phone.
An explicit `--wireless-only` launch option excludes `.wiredEthernet` in the
diagnostic browser/listener/connection parameters and rejects a ready wired path.
Normal manual runs still have no interface exclusions. This permits USB developer
launch and saved-log retrieval while attempting to test peer Wi-Fi; document that
the USB cable remains attached rather than claiming it was physically removed.
An October 3 automated run still discovered the service on wired interfaces only,
then timed out before an incoming Mac connection. A failed attempt under these
conditions does not fully isolate USB influence on discovery/resolution.
For a subsequent explicit diagnostic, `--wifi-discovery` additionally waits for a
matching result whose public interface types include Wi-Fi before selecting it.
It neither forces a connection interface nor changes the returned endpoint.
Normal runs do not apply this filter. Keep this distinction in the recorded result.
`--plain-tcp` preserves the preceding TCP comparison. The phone's `--auto-mixed`
option starts a fresh attempt after 3 seconds; prepare the server before launch.
Default NWPathMonitor events log only status/interface-type booleans and IPv4/DNS
availability, not addresses or names. A default Wi-Fi path is useful corroboration,
not an authoritative measurement of router association or an SSID lookup.

## Recorded automated comparison — October 3

With the Mac unassociated throughout and the iPhone Wi-Fi left unchanged, the
wireless-only/Wi-Fi-discovery TCP comparison was run with the registered Mac VPN
connected, disconnected, then connected again. The connected cases reached their
30-second connection deadline after Wi-Fi discovery, without a new Mac incoming
connection. Disconnected, the client became ready in 18 seconds and verified at
least ten 1024-byte echoes; server timestamps/counts agree. The successful sockets
used Wi-Fi and completed before the Mac rejoined its network. USB remained attached.

This is evidence of mixed-network transfer and a strong indication of VPN/environment
interference on the tested Mac, not a production transport fix, a general diagnosis
of all VPNs, or proof of TLS/PDF functionality. See the complete comparison and
verified network/VPN restorations in [ConnectionInvestigation](../../Docs/ConnectionInvestigation.md).
