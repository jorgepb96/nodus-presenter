# Mac/iPhone connection investigation — 2–3 October 2026

Status: the October 3 independent TCP A/B/A comparison succeeds with the Mac unassociated and the iPhone left on Wi-Fi only when the registered Mac Tailscale VPN is disconnected. However, subsequent physical tests of the actual Nodus desktop session and mobile build 14 still time out before control TLS with that VPN disconnected. Tailscale is therefore an observed interference in the independent probe, not a sufficient explanation or verified fix for Nodus. Router-free Nodus images/PDF remain unvalidated. Temporary Wi-Fi preferences, the original network, and the Connected VPN state have been restored and verified. The owner's earlier clarification that build-14 success on October 2 followed rejoining infrastructure remains authoritative. TestFlight remains 0.2.0 (11); the installed Mac implementation and main repository remain unchanged.

## Actual Nodus physical retest — October 3 morning

The owner authorized testing the remaining app flow. Tests used the installed
Nodus 5.7.4 application and its unchanged bundled native helper, an actual
Presenter session from its library, and the installed physical iOS DEBUG build
0.2.0 (14). Each pairing was obtained from the current native QR through a local,
one-use QA file. No QR credentials or document content entered the diagnostic
output. USB remained attached for device launch and log retrieval; build 14's
explicit wireless QA prohibits wired Ethernet/USB for both app channels.

Three counted windows had the Mac Wi-Fi radio on, PHY zero throughout sampled
checks, and the registered Tailscale service Disconnected throughout:

| Window (Europe/Madrid) | Current mobile launch | Result before infrastructure restoration |
| --- | --- | --- |
| 06:42:25–06:43:08 | 06:42:27 | Exact-session discovery; control preparation; 30-second deadline at 06:42:57; no TLS/state/resources |
| 07:01:40–07:02:22 | 07:01:41 | New desktop session; discovery/preparation; deadline at 07:02:12; no TLS/state/resources |
| 07:39:39–07:40:20 | 07:39:39 | Another current QR; discovery/preparation; deadline at 07:40:11; no TLS/state/resources |

The third session was created while the Mac was unassociated, but the Mac rejoined
infrastructure before this later counted phone attempt and was then disassociated
again. It is **not** a pure first-discovery-without-infrastructure experiment and
does not rule out Bonjour cache/path selection. The phone's Wi-Fi settings were
not changed. Unlike the independent probe, build 14 does not have the probe's
additional Wi-Fi-result discovery filter; excluding USB from a connection alone
does not prove how its Bonjour result was learned.

The logs report a satisfied Wi-Fi path listing `en0` while preparation stalls.
Those fields do not prove live peer traffic or identify a TLS negotiation fault:
Network's preparation includes resolution and lower-layer connection setup.
There are no authenticated state, decoded-image, or verified-PDF events in these
counted windows. Resource verification is consequently blocked by control-channel
establishment, not evidence of another asset-transfer regression.

Aborted setup attempts are excluded: one Mac immediately joined another saved
network, one VPN rollback had already restored Connected before the trial could
start, and two attempts to launch immediately after an offline QR capture exceeded
their setup deadline before launching the phone. They provide no successful or
failed app-transfer observation. Later events after network restoration are not
counted as router-free validation.

Auto Join was restored to on for all three temporarily changed saved networks,
Personal Hotspot joining to Automatic, and the original infrastructure connection
was verified in the native Wi-Fi UI with the radio enabled. Tailscale was restarted
and read back Connected; task-owned rollback markers were then cleared. IPv6,
firewall permissions, security settings, production code and TestFlight were not
changed. No release is warranted by these results. The remaining discriminating
comparison is fresh wireless-only discovery/TLS in the independent probe versus
Nodus, accounting for cable-learned/cached discovery, before making a production
change.

## Independent reproducer prepared at 19:05 (Europe/Madrid)

The owner authorized the standalone Apple-sample-based test. Sources and procedure
are in [Tools/PeerLinkProbe](../Tools/PeerLinkProbe/README.md). This is an adaptation
of TicTacToe's Bonjour/TLS-PSK setup, not the unmodified sample. It uses a separate
signed native macOS app and iOS app, separate Bonjour service types and bundle IDs,
no Nodus imports, and only synthetic 1024-byte echo messages. The browser is stopped
before connecting; no interface is forced or excluded. Manual baseline/offline
buttons open fresh connections and record the declared physical conditions.

Both app builds succeeded with Apple Development signing. A real TLS connection to
the running Mac listener echoed a matching 1024-byte block over loopback at 19:04:16;
this checks the diagnostic itself and **does not test wireless connectivity**. The
Mac server was restarted and left ready. The phone app was installed successfully;
remote launch was refused because the phone was locked. The owner has been asked to
open Peer Link Test, grant its separate Local Network permission, and run the
baseline on the existing network before changing conditions.

At 19:08:23 the owner started the physical infrastructure baseline. The iPhone
discovered the service at 19:08:25 and completed TLS at 19:08:28 (about four seconds
after starting). Both devices recorded `wifi:en0`, and the phone verified 75
1024-byte echo responses by 19:09:45. The owner also confirmed a steadily increasing
counter above 60. This validates discovery, TLS and bidirectional data on the
existing Wi-Fi network; it does not validate the unassociated case. The owner has
now been asked to remove USB, disassociate both devices without disabling Wi-Fi or
enabling Personal Hotspot, then tap the fresh offline-test button and wait up to
60 seconds before restoring connectivity.

The owner reports that the fresh offline TLS attempt stayed at zero responses,
then timed out. Phone log: at 19:10:37 a new declared-offline run discovered a
service whose result listed `wifi:en0`, entered connection preparation, and reached
its connection deadline at 19:11:09. Discovery could involve cached Bonjour data;
it is not proof of a new live peer advertisement. Mac log: the previous connection
lost viability at 19:10:34; there was **no new incoming connection** corresponding
to the offline attempt. The old path became viable again at 19:11:05 when the owner
restored infrastructure and subsequently closed. No offline transfer succeeded.
This reproduces a similar failure in the independent sample adaptation, without
Nodus document/QR/session code. It does not yet establish an OS bug or distinguish
TCP establishment from TLS negotiation.

At 19:13:02 the independent Mac probe was switched to its synthetic-data-only TCP
mode, with TLS disabled. The owner was asked to match that setting on iPhone,
confirm an infrastructure TCP baseline, and repeat offline with USB removed and
the Mac probe listener restarted **after** disassociation. This secondary test uses
a different Bonjour service type to avoid pairing different transport modes. The
Production Nodus encryption and network settings remain intact.

The repeated physical TCP test at 23:19–23:21 (Europe/Madrid) reproduced the fault
without TLS. Phone baseline: discovery and TCP became ready at 23:19:52 and at least
25 synthetic echo blocks were verified by 23:20:17. The old Mac path lost viability
at 23:20:20. The owner restarted the Mac listener after disassociation at 23:20:26;
it reported ready. The phone started fresh declared-offline browsing at 23:20:32,
found a service listing `wifi:en0`, entered connection preparation, then timed out
at 23:21:03. No new incoming connection was recorded on the Mac after the listener
restart. The owner's displayed message matches the log. Thus the reproducer also
fails at basic TCP establishment without TLS, with a fresh server; no router-free
data transfer succeeded. This narrows the investigation to discovery/resolution,
peer path establishment, OS policy or the environment, without proving which one.

A read-only recheck still reports Tailscale connected. The next proposed comparison
is the same offline TCP test with that VPN temporarily disconnected and then
restored. It has not been performed or authorized yet; it affects the whole Mac's
networking rather than only the diagnostic app.

The owner has been asked for this temporary VPN comparison. Read-only Tailscale CLI
status reports backend `Stopped` and no selected exit node, while macOS reports the
registered Tailscale Network Extension VPN `Connected` with OnDemandEnabled true.
This discrepancy does not establish an active encrypted tunnel, traffic filtering,
or causation, but means the system VPN connection remains a variable to isolate.
No VPN disconnect, uninstall or preference change has been performed.

The owner subsequently authorized temporary VPN disconnection and restoration.
`Tailscale down` reported it was already stopped and left the registered macOS
VPN connected. `scutil --nc stop Tailscale` then disconnected that registered
connection; read-back confirmed `Disconnected` and OnDemandEnabled false (original
state: Connected, OnDemandEnabled true). The diagnostic TCP listener was restarted.
The owner was asked to repeat the same fresh offline test. A local five-minute
rollback was armed in case the interaction is interrupted; it requests reconnection
of the existing service, without logout, configuration removal or changed accounts.
This is an environment experiment, not a change to Nodus.

### TCP result with the registered VPN disconnected

The owner reports that the test appeared to work when the Mac was disconnected
from its router and the iPhone was disconnected using Control Center. The Mac log
records a fresh TCP listener at 23:28:36 (Europe/Madrid), an incoming connection
ready at 23:28:49, a Wi-Fi path listing `awdl0`, and 25 echoed 1024-byte blocks by
23:29:14. The owner stopped it at 23:29:17. This is evidence of bidirectional traffic
in the independent probe under the owner's reported no-router conditions; it does
not establish a TLS or Nodus document transfer. Initial retrieval of the phone's
saved log failed because CoreDevice could not find the disconnected phone. After
the owner reconnected USB, retrieval succeeded at 23:36:27. The saved phone log
matches the Mac: fresh client start at 23:28:48, discovery listing `wifi:awdl0` and
TCP ready at 23:28:49, followed by 25 verified 1024-byte responses by 23:29:14. Thus
client-side byte validation and both device timelines agree. The USB retrieval
occurred after the recorded test and does not turn it into a wired test.

The owner additionally reports failure when the iPhone remains associated with its
router while the Mac is unassociated. The exact timing and VPN state for that mixed
attempt have not been independently matched to both device logs. VPN state and
iPhone association changed together in the successful experiment, so the result
does not isolate Tailscale as the cause. Neither Apple's documented peer mechanism
nor this test establishes a requirement to disconnect both devices from routers.

After the owner responded, the existing Tailscale service was started again.
Read-back confirmed `Connected` and `OnDemandEnabled : TRUE`, matching its original
registered connection state. The fallback rollback marker was removed, and the
armed fallback completed without making further changes. No logout, account,
firewall, app or production transport changes were made.

The remaining discriminating case is a fresh connection with the Mac unassociated
and iPhone associated, with the VPN condition held constant. A cached discovery
result, endpoint/interface scope, coexistence or OS/VPN policy remains a hypothesis,
not a demonstrated root cause. Review saved phone logs before requesting another
physical test. Production must continue to use supported automatic path selection
rather than forcing a private peer interface or changing the owner's Wi-Fi setup.

The saved phone log contains no later mixed-network attempt after the successful
23:28:48 run. The mixed failure remains owner-reported, not an independently timed
failure trace. Earlier attempts that timed out discovered a result listing `en0`;
the successful run discovered `awdl0`. Browser-result interfaces alone do not show
whether the selected service endpoint itself was scoped, and do not prove the
failed result was stale. Revision 2 of the diagnostic records endpoint scope and
uses a previously unused exact service name for a first mixed-network comparison.
The initial revision does not alter connection parameters, returned endpoints,
production code or VPN settings. At this preparation point, no additional physical
test had yet been run with revision 2.
Both revision-2 app builds succeeded at 23:39:53; their build numbers are 2 and
Apple Development signature verification succeeds. These are prepared artifacts,
not a new installed Presenter/TestFlight build. The owner has been asked whether
they can run a controlled mixed-network comparison now; no further VPN change is
planned for it. Keep that restored VPN condition fixed in the comparison.

## Automated mixed-network comparison — October 3

The owner authorized automatic execution with the physical iPhone and Mac unlocked.
The separate diagnostic apps were rebuilt and installed using Apple Development
signatures; these are not new Presenter release/TestFlight binaries. The production
Mac implementation and application/helper remain untouched.

The Mac is disassociated using public CoreWLAN while its Wi-Fi radio remains on.
Before disassociation and every five seconds during the window, the coarse public
PHY state is recorded: it remains zero during each counted run. The native Wi-Fi UI
also shows no connection before restoration, and the original saved network after
restoration. Auto Join on the three available saved networks and automatic Personal
Hotspot joining are temporarily disabled so another network cannot invalidate the
condition. No passwords, SSIDs, BSSIDs, addresses or production QR data are recorded
in probe logs. The iPhone Wi-Fi settings are not changed; its default path continues
to report satisfied Wi-Fi with IPv4/DNS, without cellular or wired use. This is
corroboration rather than an SSID measurement.

USB remains physically attached for developer launch and log retrieval. The explicit
`--wireless-only` diagnostic excludes `.wiredEthernet` from connection parameters
and rejects a ready wired path. An initial attempt was invalidated after the Mac
automatically joined another saved network; its echo is **not** an offline pass.
A later unassociated-Mac attempt discovered the service solely on wired interfaces
and timed out. That result does not fully isolate USB's influence on discovery.

For the A/B/A comparison below, an additional diagnostic-only `--wifi-discovery`
option waits for the exact service to be discovered on a public interface of type
Wi-Fi before selecting it. Each run uses a new synthetic service identity, the same
TCP parameters, unchanged returned endpoint, and the same physical conditions.
No private interface is forced. Both failing runs discover the service on a peer
Wi-Fi interface before attempting the connection, rather than consuming an
exclusively wired discovery result.

Times below are Europe/Madrid on October 3; local records contain UTC timestamps.

| Registered Mac VPN | Fresh client start | Result before restoring Mac Wi-Fi |
| --- | --- | --- |
| Connected / OnDemand true | 01:10:30 | Wi-Fi service discovered; connection remained preparing and reached its 30-second deadline at 01:11:01. No new Mac incoming connection. |
| Disconnected / OnDemand false | 01:22:53 | Connection ready at 01:23:12 (logged client elapsed 18 s). Both peers used Wi-Fi; the phone verified at least ten matching 1024-byte echoes by 01:23:22. Mac remained unassociated throughout. |
| Connected / OnDemand true, restored | 01:32:37 | Wi-Fi service discovered; connection again remained preparing and reached its deadline at 01:33:08. No new Mac incoming connection. |

Client and server logs agree on the successful ready time and synthetic-byte counts.
The Mac's VPN-specific system log confirms Disconnected at 01:22:38.827, before
the successful run's disassociation/start, and still records Disconnected at
01:23:26.261. The four-minute fallback restores Connected at 01:26:38.010, after
the successful test window and before the reverse comparison. This confirms that
the rollback did not reconnect the VPN during the successful data transfer.
The success precedes Mac network restoration and cannot be attributed to rejoining
a router or a ready wired socket. The reversed VPN comparison materially strengthens
the environment-interference hypothesis. It does not prove that Tailscale always
blocks peer Wi-Fi, explain the Network Extension policy, or establish that the
same production session will transfer TLS/PDF/images successfully. USB was not
removed, and the Bonjour-discovery filter is an explicit deviation used only for
this experiment. A production fix/release must not be inferred from this result.

Restoration was completed and read back: all three saved-network Auto Join toggles
are on, Personal Hotspot joining is Automatic, Wi-Fi is enabled and the Mac is back
on its original network. The registered VPN again reports Connected and
OnDemandEnabled true. The armed fallback marker was cleared only after that
verification; no fallback is pending. Diagnostic Mac servers were stopped before
network restoration. Firewall, credentials, accounts, extensions and the earlier
restored IPv6 preference were not changed. No additional production build was
uploaded or submitted for App Review.

A read-only environment check found the macOS firewall enabled, block-all disabled,
and automatic allowance of Apple and downloaded signed software enabled. `scutil`
reported one connected VPN service, Tailscale; a TunnelBear network extension is
also installed/enabled, which alone does not mean its VPN is connected. These are
environment variables, not established causes. This inspection itself changed no
settings; the later, explicitly authorized VPN comparison and verified restoration
are recorded above. No firewall or extension configuration was changed.

The preceding temporary Wi-Fi service IPv6 Automatic experiment did not resolve the
failure according to the owner. The service was restored to its original IPv6 Off
setting and restoration verified. [TN3111](https://developer.apple.com/documentation/technotes/tn3111-ios-wifi-api-overview)
and [TN3151](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api)
explicitly support Apple peer-to-peer Wi-Fi without configuring an infrastructure
network, including macOS and iOS. Association with a router is not a documented
prerequisite. The missing runtime condition or integration fault remains unknown.

## Physical evidence

- The owner reported failure on university Wi-Fi and with infrastructure Wi-Fi disconnected while the radios remained enabled. Personal Hotspot connects promptly.
- A temporary, opt-in DEBUG build on iPhone 16 Pro Max, iOS 26.4, recorded successful TLS and a valid Presenter state over `wiredEthernet` while the USB cable was attached.
- At 09:13:00 UTC, removing USB caused POSIX 57 (`ENOTCONN`). The subsequent attempt had a satisfied Wi-Fi path but remained in preparation until its 30-second deadline. After USB returned, TLS and the Presenter state succeeded again. This is a genuine transport failure before application commands/assets, but does not identify its root cause.
- Local discovery on the Mac previously observed the active Presenter service on infrastructure and peer interfaces. Observation on the same host does not prove that the iPhone receives those advertisements.
- The owner confirmed Local Network is enabled for both apps, and Wi-Fi is enabled in iPhone Settings. The Mac firewall explicitly allows incoming connections to the installed native helper. The app and helper have Apple-issued Developer ID signatures.
- Later experimental browser runs cannot establish an Apple peer-discovery failure: when checked, the Mac Presenter session was closed and its server process absent. Verify an active server and the current QR before each test. Do not interpret absence of results without that prerequisite.

## Official Apple comparison

[Building a custom peer-to-peer protocol](https://developer.apple.com/documentation/network/building-a-custom-peer-to-peer-protocol), including its downloadable TicTacToe source, uses Bonjour services, TLS with a pre-shared key, and `includePeerToPeer` for listeners and connections. Its browser uses default `NWParameters`, enables peer-to-peer, and obtains endpoints from `NWBrowser`. Our Mac/iOS code uses the same underlying supported mechanism and declares the specific Bonjour service in both Info.plists.

[TN3213](https://developer.apple.com/documentation/technotes/tn3213-moving-from-multipeer-connectivity-to-network-framework) documents the equivalent older Network APIs and requires stopping peer browsing before initiating a selected connection. The prepared mobile implementation now follows that sequence; it has not been validated as a fix for the owner's wireless failure.

[TN3179](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy) explains the local-network requirements, denied-policy errors, helper attribution to a Mac parent app, and the importance of Apple-issued signatures. Specific declared Bonjour operations do not require adding a general multicast entitlement. Simulator success does not validate privacy behavior on physical devices.

[Apple DTS on route selection](https://developer.apple.com/forums/thread/751839) and [interface restrictions](https://developer.apple.com/forums/thread/817831) explain that enabling peer-to-peer lets the framework choose available paths; it does not provide an API to prefer the Apple peer route. Prohibiting Wi-Fi also prohibits peer Wi-Fi. Production must not hardcode private interface names or exclude Wi-Fi. A wired exclusion exists only in the explicit DEBUG experiment so Xcode USB cannot masquerade as a wireless result.

[Apple DTS troubleshooting a similar iOS 26 report](https://developer.apple.com/forums/thread/808917?page=2) recommends a minimal test, first over infrastructure, then without infrastructure, and submitting the reproducer plus Network Diagnostics/sysdiagnose if the latter fails. The thread is not confirmation that Nodus is affected by an OS bug.

## Prepared mobile changes

- Browse the declared Bonjour type using default `NWParameters`, `includePeerToPeer = true`, and no fixed domain/interface. Select only the session named by the QR, stop the browser, and connect using its returned endpoint.
- Bound discovery to 10 seconds. If no matching service appears, stop browsing before using the existing unscoped direct-resolution fallback. Keep separate 30-second connection and 10-second authenticated-state budgets. Browser failures, including Bonjour defunct-connection errors, use the existing reconnect backoff rather than overlapping browsers.
- Cancel browsing on disconnect, background suspension and retry. Generation guards reject callbacks queued by older attempts.
- Fix a concrete lifecycle defect: initial activation or an inactive/active transition caused by a permission dialog could start another attempt, replacing the connection reference without cancelling the prior socket. Keep pending attempts intact; restart after actual background suspension or a permission dialog only if the permission-blocked attempt has already stopped. Private reading survives a real background/reconnect cycle.
- Distinguish Apple's DNS policy-denied error or `NWPath.unsatisfiedReason.localNetworkDenied` from an ordinary timeout. TN3179 warns that the OS can refuse an operation before the user answers the first permission alert: keep the browser/connection waiting so granting access can recover it, and report continued lack of access after its bounded deadline. Stop periodic retries on that permission error; returning from the permission dialog or Settings starts fresh discovery if the old attempt has stopped. Ordinary timeouts describe an unresponsive session/current QR/network instead of implying that permissions were refused. Both messages are localized in all nine languages. The app does not infer a user's explicit refusal from an undetermined permission state.
- Replace the previous experimental browser variants with the production browser. Optional DEBUG diagnostics log only phase/error/interface fields; `--wireless-qa` with `--connection-diagnostics` excludes wired transport from both discovery and connections during a later explicit physical QA run. Neither this exclusion nor file-based QA pairing is included in Release.

## Local validation and limits

The final local run passes 13 Core resource/protocol/geometry tests and 15 hosted iOS regression tests on iPhone 16 Pro Max Simulator, iOS 26.3. They cover bounded discovery, exact-session selection, stopping before connection, stale callbacks, a grant during the initial permission wait, persistent permission errors, initial activation, permission-dialog transitions, real background resume and TLS/resource recovery. Actual `NWBrowser` discovers a synthetic advertised session locally. TLS-PSK/hello/state/control/assets tests use real loopback sockets, not mocked transport. Release builds pass for iOS and Mac Catalyst. The iOS Release binary contains its Bonjour declaration and none of the DEBUG QA flags or diagnostic-file storage.

A separate exploratory combined Bonjour-to-TLS test on this Mac did **not** complete: discovery returned the service, but TLS remained in preparation with a satisfied Wi-Fi path. The native macOS probe also failed with both the browser-selected endpoint and the previous unscoped direct endpoint, while a loopback connection to the same synthetic listener completed TLS and a state roundtrip. These are temporary test listeners, not the installed Nodus helper; their signatures/firewall environment differ. They do not identify the physical fault or establish that the new browser sequence fixes it. The automated tests therefore report Bonjour discovery and loopback TLS separately, with this combined-path failure retained here rather than counted as successful validation.

Those validations preceded the new route-loss change below. Build 13 has now been installed locally; no new TestFlight upload or App Review submission has been made. The owner’s physical test is pending.

## Next decisive test, when the owner is available

1. Keep an actual desktop Presenter session active and obtain its current app QR.
2. Confirm that the Mac itself sees that exact advertised service. Compare released build 11 with the prepared browser-then-connect implementation on the physical iPhone.
3. Keep a wired baseline separate from the wireless experiment. Confirm the connection path in the logs before calling a result wireless.
4. If the faithful minimal test also fails without infrastructure, collect the diagnostics Apple requests. Do not publish a speculative release or claim campus isolation/OS defect as the root cause.

DEBUG diagnostics retain bounded event/error/interface fields on the device. They do not log QR credentials, peer names, IP addresses, slides or notes, and do not upload anything. QA launch arguments and file import are excluded from Release builds. The desktop production implementation has not been changed.


## Follow-up: losing the infrastructure Wi-Fi connection

The owner reports that an established session drops as soon as the associated Wi-Fi network is disconnected. Treat this separately from failure to establish an initial connection without an access point.

### Documentation findings and concrete correction

- [Apple DTS on route selection and migration](https://developer.apple.com/forums/thread/751839): enabling peer-to-peer permits multiple candidate paths, but does not force the peer route. An established TCP connection does not migrate to a different path automatically. A new connection is necessary.
- [NWConnection.viabilityUpdateHandler](https://developer.apple.com/documentation/network/nwconnection/viabilityupdatehandler) reports whether the connection can transmit/receive. The mobile session previously waited for a terminal socket error or its 12-second application heartbeat. It now responds to a nonviable **authenticated Mac control connection** by cancelling its old channels and starting fresh Bonjour/TLS discovery through the existing bounded backoff. It preserves private reading and cached content. Nonviability before authentication does not interrupt the pending connection. Generation and connection identity checks reject stale callbacks.
- [NWConnection.betterPathUpdateHandler](https://developer.apple.com/documentation/network/nwconnection/betterpathupdatehandler) recommends opening a replacement before cancelling an otherwise usable connection. We do not disconnect healthy sessions merely because an alternative is available; this change addresses loss of viability, not proactive path optimization.
- TN3213 and the Apple sample recommend bounded TCP send/keepalive behavior. Nodus already uses an application ping/pong watchdog. No arbitrary TLS or socket timeout reduction was added to claim a cure for initial peer setup.
- [Apple’s Control Center guidance](https://support.apple.com/102412) distinguishes disconnecting from a network from powering off Wi-Fi. The owner has been asked how they disconnected; that action has not yet been confirmed. Do not infer a user configuration error or claim that Control Center universally disables third-party peer Wi-Fi.
- The [iOS 26 forum report](https://developer.apple.com/forums/thread/808917?page=2) eventually reports success in a minimal project and in the original app on another phone. Apple did not establish a general OS bug or confirm the poster’s hardware explanation. This is not evidence to label Nodus’s failure an iOS defect.

### Additional local evidence

A read-only inspection found the Mac peer interface active with IPv6 configured, and the installed helper allowed by the application firewall. Its system logs show TLS sessions using `en0`, a `No network route` event at 17:24:52 local time, brief alternative-path notifications at 17:25:11, then a lower-stack error after the TLS handshake. No completed direct-peer session was observed in that log window. These observations do not establish the initial connection failure’s cause or prove that an alternative route was usable.

Build 13 logs startup/build/QA mode, browser readiness, matching-service discovery versus timeout, connection viability, and path changes. It separates `availableInterfaces` from `usesInterfaceType` results: listing an available interface alone is not proof that packets traversed it. Interface type `wifi` alone is also not proof of infrastructure versus peer Wi-Fi. No QR keys, service identifiers, peer names, addresses or document contents are logged. `PRESENTER_WIRELESS_QA` is supplied only to this local DEBUG build; normal builds do not enable it, and Release excludes all diagnostics and interface exclusions.

### Validation of this follow-up

- 13 Core tests pass.
- 17 hosted iOS tests pass on the iPhone 16 Pro Max simulator, iOS 26.3. The two new tests inject Network’s viability event while using real TLS sockets for recovery: authenticated path loss reconnects once, preserves private reading, and rejects stale callbacks; an unauthenticated attempt survives an initial false viability event.
- Signed physical DEBUG build 0.2.0 (13) and iOS Release compile successfully. Release binary inspection confirms no diagnostic flags or local log markers.
- Installation on the owner’s phone succeeded. Remote launch was denied because the phone was locked. The owner can open this QA build manually without launch arguments; no physical peer success is claimed.
- TestFlight still contains build 11. Do not publish this as a verified wireless fix until the physical test succeeds. If fresh pairing still fails before TLS, the next discriminating experiment is Apple’s minimal peer-to-peer sample on both real devices with and without infrastructure Wi-Fi, followed by the system diagnostics Apple requests if it reproduces.


## Physical build-13 result and assets diagnosis

At 17:41 local time, device inventory unexpectedly reported build 11 again after the earlier successful build-13 installation; the owner’s screenshot also showed the old timeout message. The reason for replacement is unknown. Build 13 was reinstalled, independently verified in device inventory, and its local log confirms `launch-build-13-wirelessQA-true` at 15:42:52 UTC.

The owner then confirmed that control worked without a router but images did not. The log records:

- 15:43:28 UTC: control TLS ready, viable and receiving Presenter state, with Wi-Fi and `awdl0` on the connection path.
- 15:43:28, 15:43:49 and 15:44:12: assets remained preparing with `en0`, while control kept receiving state over its peer path.
- 15:44:37: assets finally became TLS-ready on `en0`, consistent with the owner’s report that images appeared only after joining an infrastructure network.

This isolates the missing images to establishment of the separate assets connection in this run. It is no longer appropriate to describe every physical peer connection attempt as unsuccessful. A recovered older log also contains a short successful TLS/state sequence with `awdl0` at 09:56 UTC, though its surrounding experimental conditions were not established in this follow-up.

The mobile assets connection previously reused the original Bonjour service endpoint and resolved it independently of control, allowing a different route. It now takes `control.connection.currentPath.remoteEndpoint` at each assets connection/retry, falling back to the Bonjour endpoint only if Network provides no effective remote endpoint. [Apple documents that property](https://developer.apple.com/documentation/network/nwpath/remoteendpoint) as the remote endpoint actually in use; TN3213 also describes using an established connection’s remote endpoint to bootstrap another channel. This is an implementation inference for Nodus’s second TLS channel, not an Apple guarantee of wireless success. The endpoint and its IPv6 scope are preserved without hardcoded addresses/interfaces. TLS authentication remains unchanged, and a lost control connection still goes through fresh Bonjour discovery.

Build 14 also rejects messages from replaced assets sockets within the same control generation and logs decoded thumbnails/PDF verification without logging document content. Its new regression downloads a generated thumbnail and a SHA-256 verified PDF over real TLS and verifies that the assets connection targets the authenticated control peer. Physical confirmation remains pending for this assets correction.


### Build 14 installation and first validation

Build 14 is installed and independently verified in device inventory. It was launched successfully using the owner-provided current QR through the private, one-use QA import. At 15:50:46 UTC both TLS channels became ready on `en0`; two images decoded, and the PDF passed SHA-256 verification at 15:50:48. This confirms physical download over infrastructure, not yet over the direct peer path. The owner has been asked to scan again with the Mac disassociated from infrastructure, ensuring that in-memory images/PDF cannot mask a fresh transfer failure.

All 18 hosted iOS tests pass after the assets change, as does the iOS Release build. The earlier 13 Core tests passed after the transport callback change. The signed physical candidate also builds. TestFlight has not been updated.


## Build 14 retest at 18:24 local time

The owner provided a screenshot of the new timeout alert at 18:24:21. Device inventory confirms build 14, and the native Mac helper remained running. The DEBUG log distinguishes the sequence:

- 18:23:08–10: control, images and verified PDF completed on infrastructure (`en0`).
- Further discovery/connection attempts started at 18:23:19, 18:23:34 and 18:23:41. The log does not identify whether each restart came from rescanning or lifecycle changes.
- The last attempt exceeded its 30-second budget at 18:24:12. A retry started at 18:24:13.
- At 18:24:25 control completed TLS on the direct peer path. At 18:24:26 the assets channel completed TLS on the same peer path, decoded two thumbnails, and completed SHA-256 verification of the PDF. Both channels reported Wi-Fi and `awdl0` and this build excluded USB transport.

Thus the screenshot captures a timeout before a successful retry; it is not evidence of a permanent failure or of the assets correction failing in this run. It does expose slow initial establishment and a modal timeout while automatic retries continue. The owner has been asked whether the final images appeared without rejoining a network. No additional app code, installation or TestFlight release was made during this inspection.


## Owner clarification after the 18:24 retest

The owner explicitly reports that success followed reconnecting the Mac to an infrastructure Wi-Fi network. This supersedes the inference from the path log: `awdl0` can be active while a device is also associated to an access point. The trace proves that control and resources eventually completed, but it does not validate operation without a router. The build-14 no-infrastructure failure remains unresolved. Do not label the assets correction physically validated for that scenario or publish it as a confirmed fix.

## Bonjour interface comparison — 3 October 2026

The physical DEBUG build 15 adds opt-in discovery diagnostics. `NWBrowser.Result.interfaces` reports where a service was discovered; its service endpoint can still have a nil interface. The production browser currently passes that unscoped endpoint to Network. The diagnostic comparison constructs a service endpoint with an actual interface from that result, preserving the exact service, domain and type. It does not manufacture an interface, address or IPv6 scope. Apple describes the relevant public properties in [NWBrowser.Result](https://developer.apple.com/documentation/network/nwbrowser/result) and [NWEndpoint.interface](https://developer.apple.com/documentation/network/nwendpoint/interface). This is a routing experiment, not an Apple guarantee of a preferred peer path.

All three comparisons below use the **signed helper installed inside `/Applications/Nodus.app`**, unchanged, with a local Python parent supplying a new, synthetic three-page PDF and state. The actual mobile session handles TLS-PSK, control, JPEG decoding and PDF SHA-256 verification. The parent is a fixture, not Electron's production presenter integration. USB remains physically connected for installation/log recovery, but the mobile connections and browser prohibit wired Ethernet. The Mac remains associated to its original router throughout these comparisons; Tailscale remains Connected.

| UTC window | Discovery / requested scope | Actual authenticated paths | Result |
| --- | --- | --- | --- |
| 08:17:00–08:17:20 | Wi-Fi peer interface discovered; endpoint unscoped | Infrastructure Wi-Fi for control and assets | Valid state, two decoded images and verified PDF |
| 08:18:28–08:18:48 | Infrastructure interface discovered and scoped | Infrastructure Wi-Fi for control and assets | Same successful transfer |
| 08:24:30–08:25:10 | Peer Wi-Fi interface discovered and scoped | `wifi/awdl0`, including the effective remote endpoint, for control and assets | TLS ready at 08:24:31; two decoded images and PDF verified at 08:24:32 |

The third run proves that the existing Mac helper and mobile TLS/resources protocol can communicate over the peer path while both devices retain their normal network settings and the Mac's VPN is connected. It does **not** validate initial pairing with an unassociated Mac. The first run demonstrates that the unscoped endpoint can select a different interface from the discovery result. Selection scope is therefore a concrete candidate to test in the previously failing mixed condition; it is not yet an established root cause or a production fix.

The DEBUG-only `--peer-discovery` comparison identifies a discovered Wi-Fi interface absent from the default satisfied path's Wi-Fi interface indices. It never checks a private interface name. This diagnostic heuristic is not a public API for identifying peer Wi-Fi and must not become a production requirement. Normal Release behavior is unchanged.

### Invalid experiments and safe execution

- Disabling the Wi-Fi network service while initially retaining radio power did not provide a stable radio-only condition: macOS powered off Wi-Fi within five seconds. That window is invalid, and this procedure is disabled in the local fixture.
- An earlier window automatically associated to another saved router within seconds. It does not count as a sustained mixed-condition test.
- Cutting the Mac's only Internet path also disconnects the agent, delaying subsequent UI restoration commands. Further offline tests must be armed locally **before** a cut, with an explicit owner reconnection step or a restoration mechanism verified before the test. The revised local fixture refuses to disassociate the Mac itself. In manual mode it waits for the owner to disconnect from the router with Wi-Fi radio still on, runs the comparison and restores the temporarily stopped VPN independently of the agent.
- Auto Join for the three saved networks and the Automatic hotspot preference still need restoration after this follow-up. The Wi-Fi service/radio, original network association and VPN have been restored. ScreenCaptureKit errors currently prevent reliable changes in System Settings; do not claim the remaining preferences have been restored until checked.

### Scope-only repetition and delayed alternatives

The local build-16 candidate applied the observed scope automatically when scanning a real QR. Its infrastructure-associated repetition at 08:44:50–08:45:10 UTC discovered only the peer Wi-Fi interface and used that scoped endpoint, but TLS did not complete within the roughly 19-second attempt before the fixture ended. This is not a full 30-second deadline failure, but it shows that scope alone does not reliably provide a fast connection. The build-16 selection is superseded; do not distribute it as a fix.

Build **0.2.0 (17)** therefore keeps the original unscoped Network endpoint first. Only the local `PRESENTER_WIRELESS_QA` candidate also retains Wi-Fi interfaces supplied by the matching Bonjour result as scoped alternatives. After two seconds, if no TLS path has completed, it starts at most three alternatives without cancelling the primary. It chooses exactly one TLS-authenticated path before sending hello, cancels all losers and delayed work, and uses the winner's effective remote endpoint for resources. Generation and connection identity checks reject cancelled candidates' messages and state callbacks. Cancelling, entering background or reconnecting also cancels pending alternatives. It does not identify a peer interface by name, force the peer path, or invent an IP address. Normal DEBUG/Release do not collect scoped alternatives yet; promotion requires the missing physical mixed-condition validation.

Validation:

- 13 real TLS/session recovery tests pass on iPhone 16 Pro Max Simulator iOS 18.2, including three new tests for a stalled primary recovering through an alternative with one hello and rejected late loser callbacks, a healthy primary cancelling the alternative before it starts, and disconnect cancelling delayed work.
- Nine discovery tests pass, including exact QR-session filtering of alternative routes and clearing them on cancellation. Total: **22 unique hosted tests**, all passed across the full session run and the subsequent discovery-only run.
- Signed physical build 17 installed successfully; independent device inventory confirms version 0.2.0, bundleVersion 17. The Release build succeeds and its executable excludes diagnostic flags/file-import/log markers.
- Actual installed signed Mac helper, synthetic PDF, owner phone with wired transport excluded: 08:56:24–08:56:44 UTC, Mac on its original router, VPN Connected throughout. Control and assets authenticated on infrastructure Wi-Fi at 08:56:25; two images decoded and the PDF passed SHA-256 verification at 08:56:26. The healthy original path won before the delayed alternatives started. This validates the infrastructure baseline of the new candidate, not operation without a router.
- The manually armed mixed-condition fixture expired without detecting a Mac disassociation. That run did not perform a connection test or alter the association. The owner was explicitly told not to follow the now-expired disconnection instructions. No pending automatic network-cut/restoration job remains.
- Build 17 was returned to its home screen, without the expired fixture pairing, ready to scan the real Presenter QR. The main repository, installed production Mac helper and app are unchanged. No new TestFlight/App Store upload.

### Restoration status at the end of this follow-up

The System Settings window became operable after raising the current window and rebinding after sheet changes. Hotspot access was restored to Automatic; Auto Join for the original DIGIFIBRA-PLUS-QsFf network was set on, saved, and verified on by reopening its details. The original network remains associated, Wi-Fi radio/service enabled, Tailscale Connected/OnDemand true and IPv6 Off. Auto Join for **TP-LINK_37F9** and **TP-LINK_37F9_5G** is still pending: repeated identical detail buttons cannot be resolved by the UI tool, and its scrolled row targeting selected the wrong row. No preferences were changed on that wrong row. The advanced sheet was closed; the main Wi-Fi window is left open. Do not reconnect to another router just to restore these two settings while the agent relies on Internet.


## Comparación autorizada con Multipeer — 3 de octubre de 2026

El propietario solicita aplicar el enfoque que documenta Keynote Remote y probarlo. La candidata local **0.2.0 (18)** añade `MCNearbyServiceBrowser`/`MCSession` exclusivamente para el QR v3 con `transport=multipeer`. Los QR v1/v2 conservan sus transportes. La instancia de Nodus activa el servidor alternativo solo mediante `NODUS_PRESENTER_TRANSPORT=multipeer`; la instalación habitual del Mac no se sustituye.

MCSession requiere cifrado y se añade autenticación AES-GCM con el secreto del QR para invitación, controles y recursos. La nonce nueva, presentación, dirección, canal y secuencia se autentican para impedir repetición/reflexión entre conexiones. El móvil confirma cada recurso consumido; el host limita la cola y el PDF a un bloque pendiente. Los callbacks fiables se entregan en orden a la cola principal. Desconexión, background y recuperación cancelan la sesión anterior.

La prueba real MCSession en el Mac detectó que el auxiliar necesita un bucle de eventos de Foundation para anunciar el servicio. Con `--multipeer` se utiliza ese bucle; la ruta Network mantiene su bombeo anterior. Después pasan estado/notas, acción, preview JPEG, PDF/SHA-256 y un control independiente mientras se retrasa la confirmación de un bloque. No extrapolar esta comprobación local a dos radios físicos.

También se verifica la app real del simulador contra la instancia Electron con perfil independiente y tres diapositivas sintéticas: ventana 11:34:33–11:34:35 UTC, MCSession conectada y estado autenticado, dos imágenes recibidas, PDF completo verificado y punto verde/notas visibles. Mac con su red y VPN conservadas. Es una validación de integración, no una prueba sin router.

Core: 18 pruebas pasan. Sesión/descubrimiento hospedados en iOS 26.3: 22 pruebas pasan. La implementación predeterminada del helper sigue pasando TLS, clave incorrecta, acciones, JPEG y PDF. Build física Debug y Release 18 compilan y están firmadas. Pendiente instalar en el iPhone del propietario, que figura como no disponible, y validar las condiciones inalámbricas. Sin subida a TestFlight ni cambios de configuración de red en este seguimiento.

[Apple Keynote Remote](https://support.apple.com/en-gb/guide/keynote/tan85f5c958c/mac) identifica el framework; su implementación privada no es pública. [Apple DTS](https://developer.apple.com/forums/thread/819926) explica que Network y Multipeer utilizan la misma infraestructura peer Wi-Fi. No se declara confirmada la causa original ni garantizado que este cambio la resuelva.

### Instalación física de la candidata 18

El propietario conecta su iPhone por USB. Se instala y abre la build Debug, confirmada por el inventario independiente como versión 0.2.0, bundleVersion 18. Se importa una vez el QR de la instancia Electron de prueba mediante un archivo privado, sin exponer su secreto en argumentos o registros. El diagnóstico local queda activado durante este lanzamiento.

Ventana inicial 12:25:30–12:25:47 UTC: peer descubierto, MCSession conectada, estado Presenter autenticado, dos imágenes decodificadas y PDF SHA-256 verificado en el primer segundo. La ruta predeterminada del iPhone indica cellular, pero esa ruta no identifica la interfaz de MCSession. **USB sigue conectado y MCSession no permite excluirlo con la API utilizada: este resultado no valida el enlace inalámbrico ni el caso sin router.** El Mac conserva su red y VPN. Queda pendiente retirar el cable y verificar controles, después repetir las condiciones de red por separado.

### Confirmación del propietario y candidata 19 de fluidez

Tras las instrucciones de retirar USB manteniendo el Mac en su red, el propietario responde que funciona perfectamente y que observa tirones en puntero/Spotlight/dibujo. Se registra como confirmación manual del caso inalámbrico con Mac asociado. No demuestra que ambos dispositivos sin router funcionen ni establece la causa del fallo original de Network.

El código limita posiciones no dibujadas a 30 envíos por segundo mediante descarte según Date. Multipeer además devolvía una instantánea completa por cada posición, publicando el estado de SwiftUI y escribiendo el diagnóstico en cada eco. Son factores concretos que pueden contribuir; no se dispone de una medición de frames del Mac durante el intento del propietario.

La build 0.2.0 (19), solo para la ruta Multipeer, agrupa posiciones por CADisplayLink con preferencia de 60 Hz, envía la última al terminar y cancela las pendientes al desconectar. Todos los puntos de dibujo siguen fiables. El relay Multipeer devuelve mensajes compactos de herramienta y el emisor conserva su feedback local. La ruta Network original y el renderizador de Electron se conservan. Las 25 pruebas hospedadas y tres pruebas del relay pasan; Debug/Release compilan. La candidata se instala y abre en el iPhone del propietario y el simulador conecta con imágenes/PDF. El propietario confirma después que ahora funciona perfectamente y solicita la subida a TestFlight para probar y grabar el vídeo de App Review. Se prepara la distribución 19; la valoración subjetiva no mide frames ni valida ambos dispositivos sin router. Sin cambios de red del Mac.
