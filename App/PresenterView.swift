import SwiftUI
import PresenterCore

struct PresenterView: View {
    @EnvironmentObject var session: PresenterSession
    @EnvironmentObject var preferences: PresenterPreferences
    @Environment(\.colorScheme) private var colorScheme
    @State private var showConnection = false
    @State private var dividerStart: Double?
    @State private var layoutRange = PresenterLayout.defaultRange
    var body: some View {
        VStack(spacing: 0) {
            header
            GeometryReader { geometry in
                #if NODUS_FOLDABLE_SDK
                if #available(iOS 27.1, *) {
                    ArrangementView {
                        slidePane
                    } secondary: {
                        notes
                    }
                    .arrangementViewStyle(.split)
                    .onHingeChange { _, _ in session.endActiveGesture() }
                    .padding(.horizontal, 16)
                } else { adjustableContent(size: geometry.size) }
                #else
                adjustableContent(size: geometry.size)
                #endif
            }.frame(maxWidth: 1500)
        }
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            toolDock.frame(maxWidth: 520).padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 5)
        }
        .sheet(isPresented: $session.showSlides) { SlidesSheet() }
        .sheet(isPresented: $session.showTools) { ToolsSheet(layoutRange: layoutRange).presentationDetents([.large]) }
        .sheet(isPresented: $showConnection) { connectionDetails.presentationDetents([.medium]) }
    }
    private var header: some View {
        HStack(spacing: 8) {
            Button { showConnection = true } label: {
                NodusLogo().frame(width: 36, height: 36).accessibilityHidden(true)
                    .overlay(alignment: .bottomTrailing) {
                        Circle().fill(session.connected ? Color.green : Color.red).frame(width: 9, height: 9)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2)).offset(x: 2, y: 2)
                    }
            }.accessibilityLabel("Nodus Presenter. \(session.status)").accessibilityIdentifier("connectionStatus")
                .accessibilityValue("\(preferences.theme.title), \(colorScheme == .dark ? L10n.text("Dark") : L10n.text("Light"))")
            Text(session.deckName).foregroundStyle(Color.primary).font(.subheadline.weight(.semibold)).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            timerControl
            Button { session.showSlides = true } label: { Image(systemName: "square.grid.2x2").frame(width: 40, height: 44).contentShape(Rectangle()) }
                .accessibilityLabel(L10n.text("Slides")).accessibilityIdentifier("slides")
            Button { session.showTools = true } label: { Image(systemName: "slider.horizontal.3").frame(width: 40, height: 44).contentShape(Rectangle()) }
                .accessibilityLabel(L10n.text("Settings and tools")).accessibilityIdentifier("tools")
        }.font(.system(size: 18)).foregroundStyle(preferences.theme.color).buttonStyle(.plain).padding(.horizontal, 16).padding(.vertical, 4)
    }
    private var timerControl: some View {
        HStack(spacing: 5) {
            Image(systemName: session.state.timerRunning ? "pause.fill" : "play.fill").font(.system(size: 9))
            Text(session.timerText).font(.system(size: 14, weight: .semibold, design: .monospaced)).foregroundStyle(Color.primary)
        }.frame(minWidth: 68, minHeight: 44).contentShape(Rectangle())
            .gesture(LongPressGesture(minimumDuration: 0.6).exclusively(before: TapGesture()).onEnded { result in
                guard session.canControl else { return }
                switch result {
                case .first: session.send(["type": .string("timerReset")])
                case .second: session.send(["type": .string("timerToggle")])
                }
            })
            .accessibilityElement(children: .ignore).accessibilityAddTraits(.isButton)
            .accessibilityLabel(L10n.text("Timer")).accessibilityValue("\(session.timerText), \(session.state.timerRunning ? L10n.text("Running") : L10n.text("Paused"))")
            .accessibilityHint(L10n.text("Tap to pause or start. Press and hold to reset."))
            .accessibilityIdentifier("timer")
            .accessibilityAction { session.send(["type": .string("timerToggle")]) }
            .accessibilityAction(named: L10n.text("Reset timer")) { session.send(["type": .string("timerReset")]) }
            .opacity(session.canControl ? 1 : 0.45)
    }
    private var connectionDetails: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                ConnectionBadge()
                if session.isDemo {
                    Label(L10n.text("Local demo. The controls are not connected to a Mac."), systemImage: "play.circle")
                } else if !session.connected {
                    Label(L10n.text("Last received view. You can keep reading downloaded notes while the connection recovers."), systemImage: "arrow.triangle.2.circlepath")
                } else { Label(session.macName, systemImage: "desktopcomputer") }
                Button(L10n.text("Disconnect"), role: .destructive) { showConnection = false; session.disconnect() }.buttonStyle(.bordered)
                Spacer()
            }.padding(24).navigationTitle(L10n.text("Connection")).navigationBarTitleDisplayMode(.inline)
                .toolbar(.visible, for: .navigationBar)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.text("Done")) { showConnection = false } } }
        }
    }
    @ViewBuilder private func adjustableContent(size: CGSize) -> some View {
        let image = session.image(for: session.displayedSlide)
        let ratio = image.map { Double($0.size.width / max(1, $0.size.height)) } ?? 16 / 9
        let hasNext = preferences.showNextSlide && session.displayedSlide < session.state.totalSlides
        let range = PresenterLayout.shareRange(width: Double(size.width), height: Double(size.height), aspectRatio: ratio, hasNext: hasNext)
        let share = PresenterLayout.clamp(preferences.slideShare, to: range)
        let wide = size.width >= 700
        Group {
            if wide {
                let available = max(1, size.width - 52)
                HStack(spacing: 0) {
                    slidePane.frame(width: min(available - 220, max(260, available * share)))
                    divider(vertical: true, length: available, range: range)
                    notes
                }.padding(.horizontal, 16).padding(.bottom, 4)
            } else {
                let available = max(1, size.height - 24)
                VStack(spacing: 0) {
                    slidePane.frame(height: available * share)
                    divider(vertical: false, length: available, range: range)
                    notes
                }.padding(.horizontal, 16).padding(.bottom, 4)
            }
        }.onChange(of: range, initial: true) { _, value in
            layoutRange = value
            dividerStart = nil
            let clamped = PresenterLayout.clamp(preferences.slideShare, to: value)
            if preferences.slideShare != clamped { preferences.slideShare = clamped }
        }
    }
    private func divider(vertical: Bool, length: CGFloat, range: ClosedRange<Double>) -> some View {
        RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.35))
            .frame(width: vertical ? 4 : 40, height: vertical ? 40 : 4)
            .frame(width: vertical ? 20 : nil, height: vertical ? nil : 20)
            .frame(maxWidth: vertical ? nil : .infinity, maxHeight: vertical ? .infinity : nil)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global).onChanged { value in
                if dividerStart == nil { dividerStart = PresenterLayout.clamp(preferences.slideShare, to: range) }
                let delta = vertical ? value.translation.width : value.translation.height
                preferences.slideShare = PresenterLayout.clamp((dividerStart ?? range.lowerBound) + Double(delta / length), to: range)
            }.onEnded { _ in dividerStart = nil })
            .accessibilityElement().accessibilityLabel(L10n.text("Slide and notes split"))
            .accessibilityValue(L10n.text("Slide %d percent", Int(preferences.slideShare * 100)))
            .accessibilityIdentifier("panelDivider")
            .accessibilityAdjustableAction { direction in
                preferences.slideShare = PresenterLayout.clamp(preferences.slideShare + (direction == .increment ? 0.05 : -0.05), to: range)
            }
    }
    private var slidePane: some View {
        GeometryReader { geometry in
            let image = session.image(for: session.displayedSlide)
            let ratio = image.map { $0.size.width / max(1, $0.size.height) } ?? 16 / 9
            let hasNext = preferences.showNextSlide && session.displayedSlide < session.state.totalSlides
            let canvasHeight = min(geometry.size.width / ratio, max(1, geometry.size.height - CGFloat(PresenterLayout.chromeHeight(hasNext: hasNext))))
            VStack(spacing: CGFloat(PresenterLayout.paneSpacing)) {
                HStack {
                    Text("\(session.displayedSlide) / \(session.state.totalSlides)").font(.caption.monospacedDigit().weight(.semibold))
                        .accessibilityIdentifier("slideCounter").foregroundStyle(Color.secondary)
                    Spacer()
                    Button { session.togglePreview() } label: {
                        Image(systemName: session.localPreview ? "arrow.uturn.backward" : "book").frame(width: 44, height: 44).contentShape(Rectangle())
                    }.accessibilityLabel(session.localPreview ? L10n.text("Return to the slide on screen") : L10n.text("Read without changing the screen"))
                        .accessibilityIdentifier("preview")
                }.frame(height: CGFloat(PresenterLayout.headerHeight)).buttonStyle(.plain).foregroundStyle(preferences.theme.color)
                Spacer(minLength: 0)
                SlideCanvas(page: session.displayedSlide, interactive: true).frame(maxWidth: .infinity).frame(height: canvasHeight)
                HStack(spacing: 8) {
                    Button { session.send(["type": .string("prev")]) } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44).contentShape(Rectangle())
                    }.accessibilityLabel(L10n.text("Previous")).accessibilityIdentifier("previous")
                        .disabled(session.displayedSlide <= 1 || (!session.canControl && !session.localPreview))
                    if let tool = session.selectedTool, !session.localPreview {
                        ActiveToolControls(tool: tool).id(tool.rawValue).frame(width: min(248, max(100, geometry.size.width - 104)))
                    } else { zoomControls }
                    Button { session.send(["type": .string("next")]) } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 44).contentShape(Rectangle())
                    }.accessibilityLabel(L10n.text("Next")).accessibilityIdentifier("next")
                        .disabled(session.displayedSlide >= session.state.totalSlides || (!session.canControl && !session.localPreview))
                }.font(.system(size: 18)).buttonStyle(.plain).foregroundStyle(preferences.theme.color)
                    .frame(maxWidth: .infinity).frame(height: CGFloat(PresenterLayout.navigationHeight))
                if hasNext {
                    Button { session.previewNextSlide() } label: {
                        HStack(spacing: 12) {
                            SlideCanvas(page: session.displayedSlide + 1, interactive: false, renderWidth: 240)
                                .frame(width: 90, height: 50).allowsHitTesting(false).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(L10n.text("Next")).font(.caption).foregroundStyle(.secondary)
                                Text("\(session.displayedSlide + 1) / \(session.state.totalSlides)").font(.caption.monospacedDigit())
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "eye").font(.system(size: 20)).foregroundStyle(preferences.theme.color)
                                .frame(width: 44, height: 44)
                                .background(preferences.theme.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                                .contentShape(Rectangle()).accessibilityHidden(true)
                        }.frame(maxWidth: .infinity).frame(height: CGFloat(PresenterLayout.nextPreviewHeight))
                            .padding(.horizontal, 4).contentShape(Rectangle())
                    }.buttonStyle(.plain).accessibilityLabel(L10n.text("Read the next slide privately"))
                        .accessibilityIdentifier("nextSlidePreview")
                }
                Spacer(minLength: 0)
            }
        }
    }
    private var zoomControls: some View {
        HStack(spacing: 2) {
            Button { session.adjustSlideZoom(by: -0.25) } label: { Image(systemName: "minus.magnifyingglass").frame(width: 38, height: 44).contentShape(Rectangle()) }
                .accessibilityLabel(L10n.text("Zoom out")).accessibilityIdentifier("zoomOut").disabled(!session.canControl || session.localPreview || session.state.slideZoom.scale <= 1)
            Text("\(Int(session.state.slideZoom.scale * 100)) %").font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.primary)
                .accessibilityIdentifier("slideZoomValue").accessibilityLabel(L10n.text("Zoom %d percent", Int(session.state.slideZoom.scale * 100)))
            Button { session.adjustSlideZoom(by: 0.25) } label: { Image(systemName: "plus.magnifyingglass").frame(width: 38, height: 44).contentShape(Rectangle()) }
                .accessibilityLabel(L10n.text("Zoom in")).accessibilityIdentifier("zoomIn").disabled(!session.canControl || session.localPreview || session.state.slideZoom.scale >= 5)
        }.font(.system(size: 16)).foregroundStyle(preferences.theme.color).buttonStyle(.plain).padding(.horizontal, 3)
    }
    private var toolDock: some View {
        HStack(spacing: 4) {
            ForEach(Tool.allCases) { tool in
                Button {
                    session.toggleTool(tool)
                } label: {
                    Image(systemName: tool.symbol).frame(maxWidth: .infinity).frame(height: 44).contentShape(Rectangle())
                        .background(session.selectedTool == tool ? preferences.theme.color.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 19))
                }.accessibilityLabel(tool.title).accessibilityIdentifier("tool-\(tool.rawValue)")
                    .accessibilityAddTraits(session.selectedTool == tool ? .isSelected : [])
                    .disabled(!session.canControl)
                    .accessibilityHint(session.localPreview ? L10n.text("Returns to the slide on screen before using this control.") : "")
            }
            Rectangle().fill(Color.secondary.opacity(0.2)).frame(width: 1, height: 22).padding(.horizontal, 3)
            Button { session.send(["type": .string("blackScreen")]) } label: {
                Image(systemName: session.state.blackScreen ? "sun.max.fill" : "moon.fill").frame(maxWidth: .infinity).frame(height: 44).contentShape(Rectangle())
                    .background(session.state.blackScreen ? preferences.theme.color.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 19))
            }.accessibilityLabel(L10n.text("Black screen")).accessibilityIdentifier("blackScreen")
                .accessibilityValue(session.state.blackScreen ? L10n.text("On") : L10n.text("Off")).disabled(!session.canControl)
                .accessibilityHint(session.localPreview ? L10n.text("Returns to the slide on screen before using this control.") : "")
        }.font(.system(size: 20)).foregroundStyle(preferences.theme.color).buttonStyle(.plain).padding(5).modifier(GlassPanel(radius: 28))
    }
    private var notes: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Label(L10n.text("Notes"), systemImage: "text.alignleft").font(.headline)
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    Button { session.notesFont = max(13, session.notesFont - 2) } label: { Image(systemName: "textformat.size.smaller").frame(width: 44, height: 44).contentShape(Rectangle()) }
                        .accessibilityLabel(L10n.text("Decrease text size")).accessibilityIdentifier("notesFontDecrease").disabled(session.notesFont <= 13)
                    Button { session.notesFont = min(32, session.notesFont + 2) } label: { Image(systemName: "textformat.size.larger").frame(width: 44, height: 44).contentShape(Rectangle()) }
                        .accessibilityLabel(L10n.text("Increase text size")).accessibilityIdentifier("notesFontIncrease").disabled(session.notesFont >= 32)
                }.font(.system(size: 20)).foregroundStyle(preferences.theme.color).buttonStyle(.plain)
            }
            ScrollView {
                Text(session.note.isEmpty ? L10n.text("This slide has no notes.") : session.note)
                    .font(.system(size: session.notesFont)).lineSpacing(6).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.bottom, 8)
                    .accessibilityIdentifier("presenterNotes").accessibilityValue(L10n.text("Font %d", Int(session.notesFont)))
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).id(session.displayedSlide)
        }.padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
    }
}

struct SlideCanvas: View {
    @EnvironmentObject var session: PresenterSession
    let page: Int
    let interactive: Bool
    var renderWidth: CGFloat = 1200
    @State private var pinchStart: Double?
    @State private var panStart: SlideZoom?
    @State private var suppressDragUntil = Date.distantPast
    @State private var lastZoomSent = Date.distantPast
    var body: some View {
        let _ = session.imageRevision
        let image = session.image(for: page, width: renderWidth)
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
                    if session.state.blackScreen { Color.black; Label(L10n.text("Black screen is active"), systemImage: "moon.fill").foregroundStyle(.white).font(.caption).accessibilityIdentifier("blackScreenOverlay") }
                }
            }.clipped().contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: session.selectedTool == nil || session.localPreview ? 15 : 0)
                    .onChanged { value in
                        guard interactive, Date() >= suppressDragUntil else { return }
                        if !session.localPreview && session.selectedTool == nil && session.state.slideZoom.scale > 1 {
                            if panStart == nil { panStart = session.state.slideZoom }
                            if let start = panStart, Date().timeIntervalSince(lastZoomSent) >= 1.0 / 30 {
                                lastZoomSent = Date()
                                session.setSlideZoom(scale: start.scale,
                                    originX: start.originX - Double(value.translation.width) / max(1, Double(geometry.size.width) * (start.scale - 1)) * 100,
                                    originY: start.originY - Double(value.translation.height) / max(1, Double(geometry.size.height) * (start.scale - 1)) * 100)
                            }
                        } else { session.gesture(at: CGPoint(x: value.location.x / geometry.size.width, y: value.location.y / geometry.size.height)) }
                    }
                    .onEnded { value in
                        defer { panStart = nil }
                        guard interactive, Date() >= suppressDragUntil else { return }
                        if let start = panStart {
                            session.setSlideZoom(scale: start.scale,
                                originX: start.originX - Double(value.translation.width) / max(1, Double(geometry.size.width) * (start.scale - 1)) * 100,
                                originY: start.originY - Double(value.translation.height) / max(1, Double(geometry.size.height) * (start.scale - 1)) * 100)
                        } else if session.selectedTool != nil && !session.localPreview {
                            session.gesture(at: CGPoint(x: value.location.x / geometry.size.width, y: value.location.y / geometry.size.height), ended: true)
                        } else if abs(value.translation.width) > 35 {
                            session.send(["type": .string(value.translation.width < 0 ? "next" : "prev")])
                        }
                    }, including: interactive ? .all : .none)
                .simultaneousGesture(SpatialTapGesture(coordinateSpace: .local).onEnded { value in
                    guard interactive, session.selectedTool == nil || session.localPreview, Date() >= suppressDragUntil else { return }
                    session.send(["type": .string(value.location.x < geometry.size.width / 2 ? "prev" : "next")])
                }, including: interactive ? .all : .none)
                .simultaneousGesture(MagnifyGesture().onChanged { value in
                    guard interactive, !session.localPreview, session.canControl else { return }
                    if pinchStart == nil { pinchStart = session.state.slideZoom.scale; session.endActiveGesture(); panStart = nil }
                    suppressDragUntil = .distantFuture
                    guard Date().timeIntervalSince(lastZoomSent) >= 1.0 / 30 else { return }
                    lastZoomSent = Date()
                    session.setSlideZoom(scale: (pinchStart ?? 1) * value.magnification,
                        originX: value.startAnchor.x * 100, originY: value.startAnchor.y * 100)
                }.onEnded { value in
                    if let start = pinchStart {
                        session.setSlideZoom(scale: start * value.magnification,
                            originX: value.startAnchor.x * 100, originY: value.startAnchor.y * 100)
                    }
                    pinchStart = nil; suppressDragUntil = Date().addingTimeInterval(0.2)
                }, including: interactive ? .all : .none)
        }.aspectRatio(ratio, contentMode: .fit).clipShape(RoundedRectangle(cornerRadius: 14))
            .contentShape(Rectangle()).allowsHitTesting(interactive)
            .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
            .onAppear { session.requestImage(page) }.onChange(of: page) { _, value in session.requestImage(value) }
            .accessibilityLabel(L10n.text("Slide %d", page))
    }
}

struct SlidesSheet: View {
    @EnvironmentObject var session: PresenterSession
    @EnvironmentObject var preferences: PresenterPreferences
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
                            VStack { SlideCanvas(page: page, interactive: false, renderWidth: 320).allowsHitTesting(false).accessibilityHidden(true); Text("\(page)").font(.caption.monospacedDigit()) }.padding(7).contentShape(Rectangle())
                                .background(page == session.displayedSlide ? preferences.theme.color.opacity(0.15) : .clear, in: RoundedRectangle(cornerRadius: 18))
                        }.buttonStyle(.plain).accessibilityLabel(L10n.text("Slide %d", page)).accessibilityIdentifier("slide-cell-\(page)").disabled(!session.canControl && !session.localPreview)
                    }
                }.padding(20)
            }.navigationTitle(L10n.text("Slides")).toolbar(.visible, for: .navigationBar).toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.text("Close")) { dismiss() } } }
        }
    }
}

struct ToolsSheet: View {
    let layoutRange: ClosedRange<Double>
    @EnvironmentObject var session: PresenterSession
    @EnvironmentObject var preferences: PresenterPreferences
    @Environment(\.dismiss) var dismiss
    @State private var seek: Double = 0
    @State private var layoutDraft: Double = 0.42
    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("Layout")) {
                    Toggle(L10n.text("Show next slide"), isOn: $preferences.showNextSlide).accessibilityIdentifier("showNextSlide")
                    VStack(spacing: 12) {
                        HStack { Text(L10n.text("Slide %d%%", Int(layoutDraft * 100))).accessibilityIdentifier("layoutSlideShare"); Spacer(); Text(L10n.text("Notes %d%%", 100 - Int(layoutDraft * 100))) }.font(.caption).foregroundStyle(.secondary)
                        Slider(value: Binding(get: { layoutDraft }, set: { layoutDraft = PresenterLayout.clamp($0, to: layoutRange) }),
                               in: layoutRange.lowerBound...max(layoutRange.upperBound, layoutRange.lowerBound + 0.0001), onEditingChanged: { editing in
                            if !editing { preferences.slideShare = PresenterLayout.clamp(layoutDraft, to: layoutRange) }
                        }) { Text(L10n.text("Slide and notes space")) }
                            .accessibilityIdentifier("layoutSlider").disabled(layoutRange.lowerBound == layoutRange.upperBound)
                    }.padding(.vertical, 6)
                }
                Section(L10n.text("Theme")) {
                    Picker(L10n.text("Appearance"), selection: $preferences.appearance) {
                        ForEach(PresenterAppearance.allCases) { appearance in Text(appearance.title).tag(appearance) }
                    }.pickerStyle(.segmented).accessibilityIdentifier("appearancePicker")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(PresenterTheme.selectableCases) { theme in
                            Button { preferences.theme = theme } label: {
                                HStack(spacing: 8) {
                                    Circle().fill(theme.color).frame(width: 18, height: 18)
                                    Text(theme.title).font(.caption).foregroundStyle(.primary).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                                    if preferences.theme == theme { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(theme.color) }
                                }.frame(minHeight: 44).padding(.horizontal, 10)
                                    .background(theme.color.opacity(preferences.theme == theme ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain).accessibilityIdentifier("theme-\(theme.rawValue)")
                                .accessibilityAddTraits(preferences.theme == theme ? .isSelected : [])
                        }
                    }.padding(.vertical, 6)
                }
                Section(L10n.text("On screen")) {
                    Picker(L10n.text("Tool"), selection: Binding(get: { session.state.toolMode ?? "none" }, set: { session.send(["type": .string("setTool"), "tool": $0 == "none" ? .null : .string($0)]) })) {
                        Text(L10n.text("None")).tag("none")
                        ForEach(Tool.allCases, id: \.self) { tool in Label(tool.title, systemImage: tool.symbol).tag(tool.rawValue) }
                    }
                    if let tool = session.selectedTool {
                        Slider(value: Binding(get: { session.state.toolSizes[tool.rawValue] ?? 15 }, set: { session.send(["type": .string("setToolSize"), "tool": .string(tool.rawValue), "size": .number($0)]) }), in: tool.range) { Text(L10n.text("Size")) }
                        if tool == .zoom { Slider(value: Binding(get: { session.state.zoomFactor }, set: { session.send(["type": .string("setZoomFactor"), "factor": .number($0)]) }), in: 1.5...3) { Text(L10n.text("Magnification")) } }
                    }
                    HStack {
                        Text(L10n.text("Color")); Spacer()
                        ForEach(["#8b5cf6", "#ef4444", "#f59e0b", "#22c55e", "#3b82f6"], id: \.self) { hex in
                            Button { session.send(["type": .string("setToolColor"), "color": .string(hex)]) } label: {
                                Circle().fill(Color(hex: hex)).frame(width: 28, height: 28).overlay(Circle().strokeBorder(session.state.toolColor == hex ? Color.primary : .clear, lineWidth: 3))
                            }.buttonStyle(.plain).accessibilityLabel(L10n.text("Color %@", hex))
                        }
                    }
                    Button(L10n.text("Clear drawings")) { session.send(["type": .string("clearDraw")]) }
                    Button(L10n.text("Reset slide zoom")) { session.send(["type": .string("slideZoom"), "data": .object(["scale": .number(1), "originX": .number(50), "originY": .number(50)])]) }
                }.disabled(!session.canControl)
                Section(L10n.text("Audio")) {
                    Slider(value: Binding(get: { session.volume }, set: { session.setVolume($0) }), in: 0...100) { Text(L10n.text("Mac volume")) }.disabled(!session.canControl)
                }
                if session.videos[String(session.state.currentSlide)] != nil {
                    Section(L10n.text("Slide video")) {
                        Button(session.state.videoPlaying ? L10n.text("Pause video") : L10n.text("Play video")) { session.send(["type": .string("videoToggle")]) }
                        HStack { TextField(L10n.text("Seconds"), value: $seek, format: .number).keyboardType(.decimalPad); Button(L10n.text("Go")) { session.send(["type": .string("videoSeek"), "time": .number(max(0, seek))]) } }
                        if session.isDemo { Text(L10n.text("The demo simulates the video state.")).font(.caption).foregroundStyle(.secondary) }
                    }.disabled(!session.canControl)
                }
            }.onAppear { layoutDraft = PresenterLayout.clamp(preferences.slideShare, to: layoutRange) }
                .onChange(of: layoutRange) { _, range in layoutDraft = PresenterLayout.clamp(layoutDraft, to: range) }
                .onDisappear { preferences.slideShare = PresenterLayout.clamp(layoutDraft, to: layoutRange) }.navigationTitle(L10n.text("Settings")).toolbar(.visible, for: .navigationBar).toolbar { ToolbarItem(placement: .confirmationAction) { Button(L10n.text("Done")) { dismiss() }.accessibilityIdentifier("dismissTools") } }
        }
    }
}
