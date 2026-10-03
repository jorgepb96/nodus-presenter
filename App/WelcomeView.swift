import PresenterCore
import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var session: PresenterSession
    @EnvironmentObject private var preferences: PresenterPreferences
    let onScan: () -> Void
    let onPaste: () -> Void

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height, geometry.size.width >= 600 {
                // A fixed vertical stack wastes the available width in landscape.
                // Only unusually large accessibility text needs the scroll fallback.
                ViewThatFits(in: .vertical) {
                    landscape(compact: geometry.size.height < 500, width: geometry.size.width)
                    ScrollView { landscape(compact: true, width: geometry.size.width) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 28) {
                        brand(compact: false).padding(.top, 48)
                        connectionCard(compact: false)
                        demoButton
                        pasteButton
                        PresenterPrivacyLink().font(.footnote)
                    }
                    .frame(maxWidth: 520).padding(24).frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func landscape(compact: Bool, width: CGFloat) -> some View {
        HStack(spacing: compact ? 28 : 48) {
            brand(compact: compact)
                .frame(maxWidth: compact ? min(240, width * 0.28) : 320)
            VStack(spacing: compact ? 12 : 20) {
                connectionCard(compact: compact)
                HStack(spacing: 12) {
                    demoButton.frame(maxWidth: .infinity)
                    pasteButton.frame(maxWidth: .infinity)
                    PresenterPrivacyLink(expandsTouchTarget: true).font(.footnote)
                        .frame(maxWidth: .infinity)
                }
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: 560)
        }
        .padding(compact ? 16 : 32)
        .frame(maxWidth: 1000)
    }

    private func brand(compact: Bool) -> some View {
        VStack(spacing: compact ? 16 : 28) {
            NodusLogo().frame(width: compact ? 88 : 120, height: compact ? 88 : 120)
                .shadow(color: preferences.theme.color.opacity(0.18), radius: 24, y: 10)
            VStack(spacing: compact ? 8 : 10) {
                Text("Nodus Presenter")
                    .font(compact ? .title.bold() : .largeTitle.bold())
                Text(L10n.text("Your presentation, in your hands."))
                    .font(compact ? .subheadline : .title3).foregroundStyle(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
        }
    }

    private func connectionCard(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 20) {
            ConnectionBadge()
            if session.isPairing {
                Button(L10n.text("Cancel connection"), role: .cancel) { session.disconnect() }
                    .frame(minHeight: 44)
            }
            Label(L10n.text("Open Presenter in Nodus and choose App iPhone–iPad. Scan its QR code to pair."), systemImage: "qrcode")
                .font(compact ? .subheadline : .body)
                .fixedSize(horizontal: false, vertical: true)
            Label(L10n.text("On Mac, keep Wi-Fi enabled for a direct link. On Windows and Linux, connect both devices to the same local network."), systemImage: "antenna.radiowaves.left.and.right")
                .font(compact ? .caption : .body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: onScan) {
                Label(L10n.text("Scan QR code"), systemImage: "qrcode.viewfinder")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent).accessibilityIdentifier("scanQR")
        }
        .padding(compact ? 16 : 24).modifier(GlassPanel())
    }

    private var demoButton: some View {
        Button { session.enterDemo() } label: {
            Label(L10n.text("Try demo"), systemImage: "play.circle.fill")
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44)
        }
        .font(.footnote).buttonStyle(.bordered).accessibilityIdentifier("demo")
    }

    private var pasteButton: some View {
        Button(action: onPaste) {
            Text(L10n.text("Paste session link"))
                .font(.footnote).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("pasteSession")
    }
}
