import SwiftUI
import PresenterCore

struct ActiveToolControls: View {
    @EnvironmentObject var session: PresenterSession
    @EnvironmentObject var preferences: PresenterPreferences
    let tool: Tool
    @State private var size = 15.0
    @State private var factor = 2.0
    @State private var editingSize = false
    @State private var editingFactor = false
    @State private var showColors = false
    @State private var lastSizeSent = Date.distantPast
    @State private var lastFactorSent = Date.distantPast
    var body: some View {
        HStack(spacing: 6) {
            if tool == .draw || tool == .pointer {
                Button { showColors = true } label: {
                    Circle().fill(Color(hex: session.state.toolColor)).frame(width: 20, height: 20)
                        .frame(width: 32, height: 44).contentShape(Rectangle())
                }.accessibilityLabel("Color de la herramienta").accessibilityIdentifier("toolColor")
                    .popover(isPresented: $showColors) {
                        HStack(spacing: 10) {
                            ForEach([preferences.theme.hex, "#ef4444", "#f59e0b", "#22c55e", "#3b82f6"], id: \.self) { color in
                                Button { session.send(["type": .string("setToolColor"), "color": .string(color)]); showColors = false } label: {
                                    Circle().fill(Color(hex: color)).frame(width: 30, height: 30).frame(width: 36, height: 44).contentShape(Rectangle())
                                }.accessibilityLabel("Color \(color)")
                            }
                        }.padding(12).presentationCompactAdaptation(.popover)
                    }
            }
            if tool == .zoom {
                HStack(spacing: 10) {
                    VStack(spacing: 0) { Text("Radio").font(.caption2).foregroundStyle(.secondary); sizeSlider }
                    VStack(spacing: 0) { Text(String(format: "%.1f×", factor)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary); factorSlider }
                }
            } else { sizeSlider }
            if tool == .draw {
                Button { session.send(["type": .string("clearDraw")]) } label: {
                    Image(systemName: "trash").frame(width: 32, height: 44).contentShape(Rectangle())
                }.accessibilityLabel("Borrar trazos").accessibilityIdentifier("clearDraw")
            }
        }.buttonStyle(.plain).disabled(!session.canControl)
            .onAppear { size = session.state.toolSizes[tool.rawValue] ?? 15; factor = session.state.zoomFactor }
            .onChange(of: size) { _, value in if editingSize { sendSize() } else if value != session.state.toolSizes[tool.rawValue] { sendSize(force: true) } }
            .onChange(of: factor) { _, value in if editingFactor { sendFactor() } else if value != session.state.zoomFactor { sendFactor(force: true) } }
            .onChange(of: session.state.toolSizes[tool.rawValue]) { _, value in if !editingSize { size = value ?? 15 } }
            .onChange(of: session.state.zoomFactor) { _, value in if !editingFactor { factor = value } }
            .onDisappear { if editingSize { sendSize(force: true) }; if editingFactor { sendFactor(force: true) } }
    }
    private var sizeSlider: some View {
        Slider(value: $size, in: tool.range, onEditingChanged: { editing in
            editingSize = editing
            if !editing { sendSize(force: true) }
        }) { Text(tool == .draw ? "Grosor" : tool == .flashlight ? "Radio de Spotlight" : "Tamaño") }
            .accessibilityIdentifier("activeToolSize")
    }
    private var factorSlider: some View {
        Slider(value: $factor, in: 1.5...3, onEditingChanged: { editing in
            editingFactor = editing
            if !editing { sendFactor(force: true) }
        }) { Text("Ampliación de la lupa") }.accessibilityIdentifier("activeZoomFactor")
    }
    private func sendSize(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastSizeSent) >= 1.0 / 30 else { return }
        lastSizeSent = Date()
        session.send(["type": .string("setToolSize"), "tool": .string(tool.rawValue), "size": .number(size)])
    }
    private func sendFactor(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastFactorSent) >= 1.0 / 30 else { return }
        lastFactorSent = Date()
        session.send(["type": .string("setZoomFactor"), "factor": .number(factor)])
    }
}
