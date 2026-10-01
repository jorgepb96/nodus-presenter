import SwiftUI
import PresenterCore

struct PresenterView: View {
    @EnvironmentObject var session: PresenterSession
    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 720
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(session.deckName).font(.title2.bold()).lineLimit(2)
                            ConnectionBadge()
                        }
                        Spacer()
                        Button { session.disconnect() } label: { Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary) }.accessibilityLabel("Desconectar")
                    }
                    if session.isDemo { Label("Demo local · Prueba los controles sin conectar un Mac", systemImage: "play.circle").font(.caption).foregroundStyle(.purple) }
                    if !session.connected && !session.isDemo { Label("Última vista recibida. Los controles estarán disponibles al reconectar.", systemImage: "arrow.triangle.2.circlepath").font(.callout).foregroundStyle(.secondary) }
                    #if NODUS_FOLDABLE_SDK
                    if #available(iOS 27.1, *) {
                        ArrangementView {
                            VStack(spacing: 14) { slideSection; controlDock; nextSlide }
                        } secondary: {
                            notes
                        }
                        .arrangementViewStyle(.split)
                        .onHingeChange { _, _ in session.endActiveGesture() }
                    } else { standardContent(wide: wide, width: geometry.size.width) }
                    #else
                    standardContent(wide: wide, width: geometry.size.width)
                    #endif
                }.padding(20).frame(maxWidth: 1440).frame(maxWidth: .infinity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { session.showSlides = true } label: { Label("Diapositivas", systemImage: "square.grid.2x2") }.accessibilityIdentifier("slides")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { session.showTools = true } label: { Label("Herramientas", systemImage: "slider.horizontal.3") }.accessibilityIdentifier("tools")
            }
        }
        .sheet(isPresented: $session.showSlides) { SlidesSheet() }
        .sheet(isPresented: $session.showTools) { ToolsSheet().presentationDetents([.medium, .large]) }
    }
    @ViewBuilder private func standardContent(wide: Bool, width: CGFloat) -> some View {
        if wide {
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 14) { slideSection; controlDock; nextSlide }.frame(maxWidth: .infinity)
                notes.frame(width: min(380, width * 0.34))
            }
        } else { slideSection; controlDock; nextSlide; notes }
    }
    private var slideSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(session.localPreview ? "Vista previa privada" : "En pantalla", systemImage: session.localPreview ? "eye" : "display")
                Spacer()
                Text("\(session.displayedSlide) / \(session.state.totalSlides)").monospacedDigit().accessibilityIdentifier("slideCounter")
            }.font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            SlideCanvas(page: session.displayedSlide, interactive: true)
            Button { session.togglePreview() } label: {
                Label(session.localPreview ? "Volver a la diapositiva en pantalla" : "Leer sin cambiar la pantalla", systemImage: session.localPreview ? "arrow.uturn.backward" : "book")
            }.font(.caption).accessibilityIdentifier("preview")
        }
    }
    @ViewBuilder private var controlDock: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 12) { VStack(spacing: 12) { controls; quickTools } }
        } else { VStack(spacing: 12) { controls; quickTools } }
    }
    private var quickTools: some View {
        HStack(spacing: 5) {
            ForEach(Tool.allCases) { tool in
                Button {
                    session.send(["type": .string("setTool"), "tool": session.selectedTool == tool ? .null : .string(tool.rawValue)])
                } label: {
                    VStack(spacing: 5) { Image(systemName: tool.symbol).font(.body); Text(tool.title).font(.caption2) }
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .background(session.selectedTool == tool ? Color(hex: "#8b5cf6").opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 17))
                }.accessibilityIdentifier("tool-\(tool.rawValue)").accessibilityAddTraits(session.selectedTool == tool ? .isSelected : [])
            }
        }.padding(6).modifier(GlassPanel(radius: 23)).disabled(!session.canControl || session.localPreview)
    }
    private var controls: some View {
        HStack(spacing: 16) {
            Button { session.send(["type": .string("prev")]) } label: { Image(systemName: "chevron.left").frame(width: 32, height: 38) }.accessibilityLabel("Anterior").accessibilityIdentifier("previous")
                .disabled(session.displayedSlide <= 1 || (!session.canControl && !session.localPreview))
            Spacer(minLength: 0)
            Button { session.send(["type": .string("timerToggle")]) } label: {
                VStack(spacing: 2) { Text(session.timerText).font(.title3.monospacedDigit().weight(.semibold)); Text(session.state.timerRunning ? "Pausar" : "Iniciar").font(.caption2) }
            }.accessibilityLabel("Cronómetro \(session.timerText)").disabled(!session.canControl)
            Button { session.send(["type": .string("blackScreen")]) } label: { Image(systemName: session.state.blackScreen ? "sun.max.fill" : "moon.fill").frame(width: 32, height: 38) }.accessibilityLabel("Pantalla negra").accessibilityIdentifier("blackScreen").accessibilityValue(session.state.blackScreen ? "Activada" : "Desactivada").disabled(!session.canControl)
            Spacer(minLength: 0)
            Button { session.send(["type": .string("next")]) } label: { Image(systemName: "chevron.right").frame(width: 32, height: 38) }.accessibilityLabel("Siguiente").accessibilityIdentifier("next")
                .disabled(session.displayedSlide >= session.state.totalSlides || (!session.canControl && !session.localPreview))
        }.font(.title3).padding(.horizontal, 18).padding(.vertical, 9).modifier(GlassPanel())
    }
    private var nextSlide: some View {
        HStack(alignment: .top, spacing: 16) {
            if session.displayedSlide < session.state.totalSlides {
                SlideCanvas(page: session.displayedSlide + 1, interactive: false).frame(maxWidth: 190)
                VStack(alignment: .leading, spacing: 5) { Text("A continuación").font(.caption.weight(.semibold)).foregroundStyle(.secondary); Text("Diapositiva \(session.displayedSlide + 1)").font(.callout); Text("Desliza para avanzar").font(.caption).foregroundStyle(.secondary) }
            } else { Label("Última diapositiva", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary) }
            Spacer(minLength: 0)
        }
    }
    private var notes: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Notas", systemImage: "text.alignleft").font(.headline)
                Spacer()
                Button { session.notesFont = max(13, session.notesFont - 2) } label: { Image(systemName: "textformat.size.smaller") }.accessibilityLabel("Reducir texto")
                Button { session.notesFont = min(32, session.notesFont + 2) } label: { Image(systemName: "textformat.size.larger") }.accessibilityLabel("Ampliar texto")
            }
            Text(session.note.isEmpty ? "Esta diapositiva no tiene notas." : session.note).font(.system(size: session.notesFont)).lineSpacing(6).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }.padding(20).background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

struct SlideCanvas: View {
    @EnvironmentObject var session: PresenterSession
    let page: Int
    let interactive: Bool
    @State private var pinchStart: Double?
    var body: some View {
        let _ = session.imageRevision
        let image = session.image(for: page)
        let ratio = image.map { $0.size.width / max(1, $0.size.height) } ?? 16 / 9
        GeometryReader { geometry in
            ZStack {
                Color.black
                if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                        .scaleEffect(interactive && !session.localPreview ? session.state.slideZoom.scale : 1,
                                     anchor: UnitPoint(x: session.state.slideZoom.originX / 100, y: session.state.slideZoom.originY / 100))
                } else { ProgressView().tint(.white) }
                if interactive && !session.localPreview {
                    if session.selectedTool == .flashlight {
                        let diameter = geometry.size.width * (session.state.toolSizes["flashlight"] ?? 15) / 50
                        Color.black.opacity(0.78).mask {
                            Rectangle().overlay {
                                Circle().frame(width: diameter, height: diameter).position(x: session.toolPosition.x * geometry.size.width, y: session.toolPosition.y * geometry.size.height).blendMode(.destinationOut)
                            }.compositingGroup()
                        }
                    }
                    if session.selectedTool == .pointer {
                        Circle().fill(Color(hex: session.state.toolColor)).frame(width: session.state.toolSizes["pointer"] ?? 20).position(x: session.toolPosition.x * geometry.size.width, y: session.toolPosition.y * geometry.size.height)
                    }
                    if session.selectedTool == .zoom, let image {
                        let diameter = min(geometry.size.width * 0.5, session.state.toolSizes["zoom"] ?? 200)
                        Image(uiImage: image).resizable().scaledToFill().frame(width: geometry.size.width, height: geometry.size.height)
                            .scaleEffect(session.state.zoomFactor, anchor: UnitPoint(x: session.toolPosition.x, y: session.toolPosition.y))
                            .mask(Circle().frame(width: diameter, height: diameter).position(x: session.toolPosition.x * geometry.size.width, y: session.toolPosition.y * geometry.size.height))
                    }
                    Canvas { context, size in
                        for stroke in session.strokes {
                            var path = Path(); for (index, point) in stroke.points.enumerated() {
                                let p = CGPoint(x: point.x * size.width, y: point.y * size.height)
                                if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
                            }
                            context.stroke(path, with: .color(Color(hex: stroke.color)), style: StrokeStyle(lineWidth: stroke.width, lineCap: .round, lineJoin: .round))
                        }
                    }
                    if session.state.blackScreen { Color.black; Label("Pantalla negra activa", systemImage: "moon.fill").foregroundStyle(.white).font(.caption) }
                }
            }.clipped().contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: session.selectedTool == nil || session.localPreview ? 25 : 0)
                    .onChanged { value in if interactive { session.gesture(at: CGPoint(x: value.location.x / geometry.size.width, y: value.location.y / geometry.size.height)) } }
                    .onEnded { value in
                        guard interactive else { return }
                        if session.selectedTool != nil && !session.localPreview { session.gesture(at: CGPoint(x: value.location.x / geometry.size.width, y: value.location.y / geometry.size.height), ended: true) }
                        else if abs(value.translation.width) > 35 { session.send(["type": .string(value.translation.width < 0 ? "next" : "prev")]) }
                    })
                .simultaneousGesture(MagnifyGesture().onChanged { value in
                    guard interactive, !session.localPreview else { return }
                    if pinchStart == nil { pinchStart = session.state.slideZoom.scale }
                    session.send(["type": .string("slideZoom"), "data": .object(["scale": .number(min(5, max(1, (pinchStart ?? 1) * value.magnification))), "originX": .number(value.startAnchor.x * 100), "originY": .number(value.startAnchor.y * 100)])])
                }.onEnded { _ in pinchStart = nil })
        }.aspectRatio(ratio, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 14)).shadow(color: .black.opacity(0.12), radius: 12, y: 5)
            .onAppear { session.requestImage(page) }.onChange(of: page) { _, value in session.requestImage(value) }
            .accessibilityLabel("Diapositiva \(page)")
    }
}

struct SlidesSheet: View {
    @EnvironmentObject var session: PresenterSession
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 18)], spacing: 18) {
                    ForEach(1...max(1, session.state.totalSlides), id: \.self) { page in
                        Button {
                            if session.localPreview { session.localSlide = page } else { session.send(["type": .string("navigate"), "slide": .number(Double(page))]) }
                            dismiss()
                        } label: {
                            VStack { SlideCanvas(page: page, interactive: false); Text("\(page)").font(.caption.monospacedDigit()) }.padding(7)
                                .background(page == session.displayedSlide ? Color.purple.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(.plain).disabled(!session.canControl && !session.localPreview)
                    }
                }.padding(20)
            }.navigationTitle("Diapositivas").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
        }
    }
}

struct ToolsSheet: View {
    @EnvironmentObject var session: PresenterSession
    @Environment(\.dismiss) var dismiss
    @State private var seek: Double = 0
    var body: some View {
        NavigationStack {
            Form {
                Section("En pantalla") {
                    Picker("Herramienta", selection: Binding(get: { session.state.toolMode ?? "none" }, set: { session.send(["type": .string("setTool"), "tool": $0 == "none" ? .null : .string($0)]) })) {
                        Text("Ninguna").tag("none")
                        ForEach(Tool.allCases, id: \.self) { tool in Label(tool.title, systemImage: tool.symbol).tag(tool.rawValue) }
                    }
                    if let tool = session.selectedTool {
                        Slider(value: Binding(get: { session.state.toolSizes[tool.rawValue] ?? 15 }, set: { session.send(["type": .string("setToolSize"), "tool": .string(tool.rawValue), "size": .number($0)]) }), in: tool.range) { Text("Tamaño") }
                        if tool == .zoom { Slider(value: Binding(get: { session.state.zoomFactor }, set: { session.send(["type": .string("setZoomFactor"), "factor": .number($0)]) }), in: 1.5...3) { Text("Ampliación") } }
                    }
                    HStack {
                        Text("Color"); Spacer()
                        ForEach(["#8b5cf6", "#ef4444", "#f59e0b", "#22c55e", "#3b82f6"], id: \.self) { hex in
                            Button { session.send(["type": .string("setToolColor"), "color": .string(hex)]) } label: {
                                Circle().fill(Color(hex: hex)).frame(width: 28, height: 28).overlay(Circle().strokeBorder(session.state.toolColor == hex ? Color.primary : .clear, lineWidth: 3))
                            }.buttonStyle(.plain).accessibilityLabel("Color \(hex)")
                        }
                    }
                    Button("Borrar trazos") { session.send(["type": .string("clearDraw")]) }
                    Button("Restablecer zoom de la diapositiva") { session.send(["type": .string("slideZoom"), "data": .object(["scale": .number(1), "originX": .number(50), "originY": .number(50)])]) }
                }
                Section("Cronómetro y audio") {
                    Button("Reiniciar cronómetro") { session.send(["type": .string("timerReset")]) }
                    Slider(value: Binding(get: { session.volume }, set: { session.setVolume($0) }), in: 0...100) { Text("Volumen del Mac") }
                }
                if session.videos[String(session.state.currentSlide)] != nil {
                    Section("Vídeo de la diapositiva") {
                        Button(session.state.videoPlaying ? "Pausar vídeo" : "Reproducir vídeo") { session.send(["type": .string("videoToggle")]) }
                        HStack { TextField("Segundos", value: $seek, format: .number).keyboardType(.decimalPad); Button("Ir") { session.send(["type": .string("videoSeek"), "time": .number(max(0, seek))]) } }
                        if session.isDemo { Text("La demo simula el estado del vídeo.").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }.disabled(!session.canControl).navigationTitle("Herramientas").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { dismiss() } } }
        }
    }
}
