import PresenterCore
import SwiftUI

/// `NodusMark + NODUS / PRESENTER`, matching the toolbar of Nodus Reader and Drift.
struct PresenterBrandToolbar: View {
    @EnvironmentObject private var preferences: PresenterPreferences
    var body: some View {
        HStack(spacing: 7) {
            NodusMark().frame(width: 19, height: 21)
            Text(verbatim: "NODUS").font(.system(size: 11, weight: .semibold)).tracking(3)
                .foregroundStyle(preferences.theme.color)
            Text(verbatim: "/ PRESENTER").font(.system(size: 10, weight: .medium)).tracking(2)
                .foregroundStyle(.secondary)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Nodus Presenter"))
        .accessibilityAddTraits(.isHeader)
    }
}

/// Flat panel with a hairline, as used for cards across the Nodus apps.
struct NodusPanel: ViewModifier {
    var radius: CGFloat = 22
    func body(content: Content) -> some View {
        content
            .background(Color(.secondarySystemGroupedBackground).opacity(0.7), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1))
    }
}

struct WelcomeView: View {
    @EnvironmentObject private var session: PresenterSession
    @EnvironmentObject private var preferences: PresenterPreferences
    @ScaledMetric(relativeTo: .largeTitle) private var headingSize = 40.0
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
                    VStack(alignment: .leading, spacing: 24) {
                        brand(compact: false).padding(.top, 12)
                        connectionCard(compact: false)
                        VStack(spacing: 12) {
                            scanButton(compact: false)
                            demoButton(compact: false)
                        }
                        VStack(spacing: 4) {
                            pasteButton
                            PresenterPrivacyLink().font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: 520).padding(24).frame(maxWidth: .infinity)
                }
            }
        }
        .toolbar { ToolbarItem(placement: .principal) { PresenterBrandToolbar() } }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func landscape(compact: Bool, width: CGFloat) -> some View {
        HStack(spacing: compact ? 28 : 48) {
            brand(compact: compact)
                .frame(maxWidth: compact ? min(260, width * 0.3) : 340)
            VStack(spacing: compact ? 12 : 16) {
                connectionCard(compact: compact)
                HStack(spacing: 12) {
                    scanButton(compact: compact)
                    demoButton(compact: compact)
                }
                HStack(spacing: 12) {
                    pasteButton.frame(maxWidth: .infinity)
                    PresenterPrivacyLink(expandsTouchTarget: true).font(.footnote).foregroundStyle(.secondary)
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
        VStack(spacing: compact ? 14 : 22) {
            Text(L10n.text("You run the show."))
                .font(.system(size: compact ? headingSize * 0.75 : headingSize, design: .serif))
                .tracking(compact ? -0.7 : -1)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            VStack(spacing: compact ? 10 : 14) {
                NodusLogo().frame(width: compact ? 80 : 112, height: compact ? 80 : 112)
                    .shadow(color: preferences.theme.color.opacity(0.18), radius: 24, y: 10)
                statusEyebrow
            }
        }
    }

    private var statusEyebrow: some View {
        HStack(spacing: 6) {
            Circle().fill(session.connected ? Color.green : Color.red).frame(width: 5, height: 5)
            Text(session.status).font(.system(size: 10, weight: .medium)).tracking(2)
                .textCase(.uppercase).foregroundStyle(.secondary).lineLimit(2)
        }
        .accessibilityElement(children: .combine).accessibilityIdentifier("connectionStatus")
    }

    private func connectionCard(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 12 : 18) {
            Label(L10n.text("Open Presenter in Nodus and choose App iPhone–iPad. Scan its QR code to pair."), systemImage: "qrcode")
                .font(compact ? .subheadline : .callout)
                .fixedSize(horizontal: false, vertical: true)
            Label(L10n.text("On Mac, keep Wi-Fi enabled for a direct link. On Windows and Linux, connect both devices to the same local network."), systemImage: "antenna.radiowaves.left.and.right")
                .font(compact ? .caption : .footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if session.isPairing {
                Button(role: .cancel) { session.disconnect() } label: {
                    Text(L10n.text("Cancel connection")).font(.subheadline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(compact ? 16 : 22).modifier(NodusPanel())
    }

    private func scanButton(compact: Bool) -> some View {
        Button(action: onScan) {
            Label(L10n.text("Scan QR code"), systemImage: "qrcode.viewfinder")
                .font(.system(size: 15, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity, minHeight: compact ? 48 : 54)
                .background(preferences.theme.color, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).accessibilityIdentifier("scanQR")
    }

    // Same footprint as the scan button, outlined like the secondary pills in Reader and Drift.
    private func demoButton(compact: Bool) -> some View {
        Button { session.enterDemo() } label: {
            Label(L10n.text("Try demo"), systemImage: "play.fill")
                .font(.system(size: 15, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: compact ? 48 : 54)
                .overlay(Capsule().stroke(preferences.theme.color.opacity(0.45), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain).foregroundStyle(.primary).accessibilityIdentifier("demo")
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
