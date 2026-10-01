import PresenterCore
import SwiftUI

@main struct NodusPresenterApp: App {
    @StateObject private var session = PresenterSession()
    @StateObject private var preferences = PresenterPreferences()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(session).environmentObject(preferences).tint(preferences.theme.color)
                .preferredColorScheme(preferences.appearance.colorScheme)
                .environment(\.locale, L10n.locale)
                .onOpenURL { session.connect(url: $0) }
                .onChange(of: phase) { _, value in session.sceneChanged(value) }
        }
    }
}

struct GlassPanel: ViewModifier {
    var radius: CGFloat = 24
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: radius))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
        }
    }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.dropFirst(), radix: 16) ?? 0x8b5cf6
        self.init(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
}

struct ConnectionBadge: View {
    @EnvironmentObject var session: PresenterSession
    var body: some View {
        HStack(spacing: 7) {
            Circle().fill(session.connected ? Color.green : Color.red).frame(width: 8, height: 8)
            Text(session.status).font(.caption.weight(.medium)).lineLimit(2)
        }.accessibilityElement(children: .combine).accessibilityIdentifier("connectionStatus")
    }
}

struct RootView: View {
    @EnvironmentObject var session: PresenterSession
    @EnvironmentObject var preferences: PresenterPreferences
    @State private var scanning = false
    @State private var pairingText = ""
    @State private var manual = false
    var body: some View {
        NavigationStack {
            Group {
                if session.state.presenting { PresenterView() }
                else {
                    ScrollView {
                        VStack(spacing: 28) {
                            NodusLogo().frame(width: 120, height: 120)
                                .shadow(color: preferences.theme.color.opacity(0.18), radius: 24, y: 10)
                                .padding(.top, 48)
                            VStack(spacing: 10) {
                                Text("Nodus Presenter").font(.largeTitle.bold()).multilineTextAlignment(.center)
                                Text(L10n.text("Your presentation, in your hands.")).font(.title3).foregroundStyle(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 20) {
                                ConnectionBadge()
                                if session.isPairing { Button(L10n.text("Cancel connection"), role: .cancel) { session.disconnect() } }
                                Label(L10n.text("Open Presenter in Nodus and choose App iPhone–iPad. Scan its QR code to pair."), systemImage: "qrcode")
                                Label(L10n.text("On Mac, keep Wi-Fi enabled for a direct link. On Windows and Linux, connect both devices to the same local network."), systemImage: "antenna.radiowaves.left.and.right")
                                Button { scanning = true } label: { Label(L10n.text("Scan QR code"), systemImage: "qrcode.viewfinder").frame(maxWidth: .infinity).padding(.vertical, 6) }
                                    .buttonStyle(.borderedProminent).accessibilityIdentifier("scanQR")
                            }.padding(24).modifier(GlassPanel())
                            Button { session.enterDemo() } label: { Label(L10n.text("Try demo"), systemImage: "play.circle.fill") }
                                .buttonStyle(.bordered).accessibilityIdentifier("demo")
                            Button(L10n.text("Paste session link")) { manual = true }.font(.footnote)
                            PresenterPrivacyLink().font(.footnote)
                        }.frame(maxWidth: 520).padding(24).frame(maxWidth: .infinity)
                    }
                }
            }.background {
                Color(.systemBackground).overlay {
                    LinearGradient(colors: [preferences.theme.color.opacity(0.10), .clear, preferences.theme.color.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
                }.ignoresSafeArea()
            }
            .sheet(isPresented: $scanning) { QRScanner { url in scanning = false; session.connect(url: url) } }
            .alert(L10n.text("Pair with Nodus"), isPresented: $manual) {
                TextField("nodus-presenter://pair…", text: $pairingText).textInputAutocapitalization(.never)
                Button(L10n.text("Connect")) { if let url = URL(string: pairingText) { session.connect(url: url) } }
                Button(L10n.text("Cancel"), role: .cancel) {}
            }
            .alert("Nodus Presenter", isPresented: Binding(get: { session.errorMessage != nil }, set: { if !$0 { session.errorMessage = nil } })) {
                Button(L10n.text("OK")) { session.errorMessage = nil }
            } message: { Text(session.errorMessage ?? "") }
        }
    }
}

struct PresenterPrivacyLink: View {
    private let policyURL = URL(string: "https://nodusresearch.com/presenter/privacy/")!
    var body: some View {
        Link(destination: policyURL) {
            Label(L10n.text("Privacy policy"), systemImage: "hand.raised")
        }.accessibilityIdentifier("privacyPolicy")
    }
}
