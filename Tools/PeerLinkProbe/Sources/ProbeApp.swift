import SwiftUI
#if os(iOS)
import UIKit
#endif

@main
struct ProbeApp: App {
    @StateObject private var model = ProbeModel()
    var body: some Scene {
        WindowGroup {
            ProbeView(model: model)
                .onAppear {
                    let arguments = ProcessInfo.processInfo.arguments
                    if arguments.contains("--plain-tcp") { model.tls = false }
                    #if os(iOS)
                    UIApplication.shared.isIdleTimerDisabled = true
                    if arguments.contains("--auto-mixed") {
                        model.status = "Preparando prueba automática · 3 s"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            model.start("Mixta · automática · confirmar asociación por separado")
                        }
                    } else if arguments.contains("--auto-client") { model.start("Con red · baseline") }
                    #else
                    model.start("Servidor independiente")
                    #endif
                }
        }
    }
}

struct ProbeView: View {
    @ObservedObject var model: ProbeModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("Peer Link Test", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.largeTitle.bold())
                Text("Diagnóstico independiente basado en el ejemplo de Apple")
                    .foregroundStyle(.secondary)
                HStack {
                    Circle().fill(model.connected ? .green : .orange).frame(width: 12, height: 12)
                    Text(model.status).font(.headline)
                }
                Text(model.path).font(.caption.monospaced()).textSelection(.enabled)
                HStack(spacing: 28) {
                    VStack(alignment: .leading) { Text("\(model.roundTrips)").font(.title); Text(model.hosting ? "Bloques devueltos" : "Respuestas verificadas").font(.caption) }
                    VStack(alignment: .leading) { Text("\(model.bytesReceived / 1024) KB").font(.title); Text("Datos de prueba").font(.caption) }
                }
                Picker("Función", selection: $model.hosting) {
                    Text("Servidor").tag(true)
                    Text("Cliente").tag(false)
                }.pickerStyle(.segmented).disabled(model.running)
                Toggle("TLS (configuración del ejemplo Apple)", isOn: $model.tls).disabled(model.running)
                if model.hosting {
                    Button("Reiniciar servidor") { model.start("Servidor independiente") }.buttonStyle(.borderedProminent)
                } else {
                    Button("1. Probar con red") { model.start("Con red · declarado por usuario") }.buttonStyle(.borderedProminent)
                    Button("2. Nueva prueba sin red") { model.start("Sin red · declarado por usuario") }.buttonStyle(.borderedProminent)
                    Button("3. iPhone con red · Mac sin red") {
                        model.start("Mixta · iPhone asociado / Mac no asociado · declarado por usuario")
                    }.buttonStyle(.borderedProminent)
                    Text("Para la segunda prueba: desconecta la red, conserva Wi-Fi encendido y retira el cable USB. Pulsa después el botón: se abrirá una conexión nueva.")
                        .font(.callout)
                }
                Button("Detener") { model.log("user-stop"); model.stop() }.buttonStyle(.bordered)
                Text("Condición: \(model.phase)").font(.caption)
                Text("La interfaz por sí sola no demuestra ausencia de router. Se guardan únicamente eventos técnicos y contadores locales.")
                    .font(.caption).foregroundStyle(.secondary)
                Divider()
                Text(model.events.suffix(12).joined(separator: "\n"))
                    .font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
            }.padding(24).frame(maxWidth: 650, alignment: .leading)
        }
        #if os(macOS)
        .frame(minWidth: 580, minHeight: 740)
        #endif
    }
}
