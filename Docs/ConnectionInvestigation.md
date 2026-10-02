# Mac/iPhone connection investigation — 2 October 2026

Status: the physical wireless failure remains unresolved. Documentation-based mobile corrections are prepared on the existing PR; public TestFlight remains 0.2.0 (11). No replacement has been uploaded or installed on the unavailable physical iPhone.

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

The owner cannot use the physical iPhone at present. No additional physical test, installation, TestFlight upload or App Review submission is claimed. Keep the desktop implementation unchanged and await a real-device test.

## Next decisive test, when the owner is available

1. Keep an actual desktop Presenter session active and obtain its current app QR.
2. Confirm that the Mac itself sees that exact advertised service. Compare released build 11 with the prepared browser-then-connect implementation on the physical iPhone.
3. Keep a wired baseline separate from the wireless experiment. Confirm the connection path in the logs before calling a result wireless.
4. If the faithful minimal test also fails without infrastructure, collect the diagnostics Apple requests. Do not publish a speculative release or claim campus isolation/OS defect as the root cause.

DEBUG diagnostics retain bounded event/error/interface fields on the device. They do not log QR credentials, peer names, IP addresses, slides or notes, and do not upload anything. QA launch arguments and file import are excluded from Release builds. The desktop production implementation has not been changed.
