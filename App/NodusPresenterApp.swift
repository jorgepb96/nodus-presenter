import SwiftUI

@main struct NodusPresenterApp: App {
    @StateObject private var session = PresenterSession()
    @StateObject private var preferences = PresenterPreferences()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(session).environmentObject(preferences).tint(preferences.theme.color)
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
                            Image("AppIconPreview").resizable().scaledToFit().frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 28)).shadow(color: preferences.theme.color.opacity(0.18), radius: 24, y: 10)
                                .padding(.top, 48)
                            VStack(spacing: 10) {
                                Text("Nodus Presenter").font(.largeTitle.bold())
                                Text("Tu presentación, en tus manos.").font(.title3).foregroundStyle(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 20) {
                                ConnectionBadge()
                                if session.isPairing { Button("Cancelar conexión", role: .cancel) { session.disconnect() } }
                                Label("Abre Presenter en Nodus y elige App iPhone–iPad. Escanea su QR para enlazar.", systemImage: "qrcode")
                                Label("El enlace directo puede funcionar sin el router de la sala. Mantén Wi-Fi encendido en ambos dispositivos.", systemImage: "antenna.radiowaves.left.and.right")
                                Button { scanning = true } label: { Label("Escanear QR", systemImage: "qrcode.viewfinder").frame(maxWidth: .infinity).padding(.vertical, 6) }
                                    .buttonStyle(.borderedProminent).accessibilityIdentifier("scanQR")
                            }.padding(24).modifier(GlassPanel())
                            Button { session.enterDemo() } label: { Label("Probar demo", systemImage: "play.circle.fill") }
                                .buttonStyle(.bordered).accessibilityIdentifier("demo")
                            Button("Pegar enlace de sesión") { manual = true }.font(.footnote)
                        }.frame(maxWidth: 520).padding(24).frame(maxWidth: .infinity)
                    }
                }
            }.background {
                LinearGradient(colors: [preferences.theme.color.opacity(0.10), Color(.systemBackground), preferences.theme.color.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
            }
            .sheet(isPresented: $scanning) { QRScanner { url in scanning = false; session.connect(url: url) } }
            .alert("Enlazar con Nodus", isPresented: $manual) {
                TextField("nodus-presenter://pair…", text: $pairingText).textInputAutocapitalization(.never)
                Button("Conectar") { if let url = URL(string: pairingText) { session.connect(url: url) } }
                Button("Cancelar", role: .cancel) {}
            }
            .alert("Nodus Presenter", isPresented: Binding(get: { session.errorMessage != nil }, set: { if !$0 { session.errorMessage = nil } })) {
                Button("Aceptar") { session.errorMessage = nil }
            } message: { Text(session.errorMessage ?? "") }
        }
    }
}
