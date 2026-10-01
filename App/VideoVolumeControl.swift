import SwiftUI
import PresenterCore

struct VideoVolumeControl: View {
    @EnvironmentObject var session: PresenterSession
    @EnvironmentObject var preferences: PresenterPreferences
    @State private var isOpen = false
    @State private var draft = 50.0
    @State private var editing = false
    @State private var lastSent = Date.distantPast

    var body: some View {
        Button { isOpen.toggle() } label: {
            Image(systemName: session.volume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.system(size: 17)).frame(width: 44, height: 44).contentShape(Rectangle())
                .background(preferences.theme.color.opacity(0.08), in: Circle())
        }.buttonStyle(.plain).foregroundStyle(preferences.theme.color).disabled(!session.canControl)
            .accessibilityLabel(L10n.text("Mac volume")).accessibilityValue("\(Int(session.volume)) %")
            .accessibilityIdentifier("videoVolume")
            .popover(isPresented: $isOpen) {
                VStack(spacing: 8) {
                    HStack {
                        Text(L10n.text("Mac volume")).font(.subheadline.weight(.semibold))
                        Spacer()
                        Button { isOpen = false } label: {
                            Image(systemName: "xmark").frame(width: 44, height: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel(L10n.text("Close")).accessibilityIdentifier("dismissVolume")
                    }
                    HStack(spacing: 12) {
                        Image(systemName: draft == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill").accessibilityHidden(true)
                        Slider(value: $draft, in: 0...100, step: 1, onEditingChanged: { value in
                            editing = value
                            if !value { sendVolume(force: true) }
                        }) { Text(L10n.text("Mac volume")) }.accessibilityIdentifier("videoVolumeSlider")
                            .frame(minHeight: 44)
                        Text("\(Int(draft)) %").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 44)
                    }
                }.padding(16).frame(width: 280).tint(preferences.theme.color)
                    .presentationCompactAdaptation(.popover)
            }
            .onAppear { draft = session.volume }
            .onChange(of: session.volume) { _, value in if !editing { draft = value } }
            .onChange(of: draft) { _, value in
                if editing { sendVolume() }
                else if value != session.volume { sendVolume(force: true) }
            }
            .onChange(of: isOpen) { _, value in
                if value { draft = session.volume }
                else if editing { editing = false; sendVolume(force: true) }
            }
            .onDisappear { if editing { sendVolume(force: true) } }
    }
    private func sendVolume(force: Bool = false) {
        guard force || Date().timeIntervalSince(lastSent) >= 0.08 else { return }
        lastSent = Date()
        session.setVolume(draft)
    }
}
