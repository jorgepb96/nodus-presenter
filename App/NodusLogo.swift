import SwiftUI

/// The original connected N inside a display, rendered at the current size and accent.
struct NodusLogo: View {
    @EnvironmentObject var preferences: PresenterPreferences
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let accent = preferences.theme.color
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.24)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.24)
                            .fill(LinearGradient(colors: [accent.opacity(colorScheme == .dark ? 0.16 : 0.06), accent.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.24)
                            .strokeBorder(accent.opacity(colorScheme == .dark ? 0.26 : 0.12), lineWidth: max(0.5, size / 240))
                    }
                Canvas { context, _ in
                    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x / 1024 * size, y: (1 - y / 1024) * size) }
                    let screen = Path(roundedRect: CGRect(x: size * 160 / 1024, y: size * 236 / 1024, width: size * 704 / 1024, height: size * 540 / 1024), cornerRadius: size * 64 / 1024)
                    context.stroke(screen, with: .color(accent), lineWidth: size * 25 / 1024)
                    var stand = Path()
                    stand.move(to: point(512, 248)); stand.addLine(to: point(512, 184))
                    stand.move(to: point(376, 177)); stand.addLine(to: point(648, 177))
                    context.stroke(stand, with: .color(accent), style: StrokeStyle(lineWidth: size * 25 / 1024, lineCap: .round))
                    // M18 48V16L46 48V16, scaled without changing the brand geometry.
                    let points = [point(372, 378), point(372, 698), point(652, 378), point(652, 698)]
                    var mark = Path(); mark.move(to: points[0]); points.dropFirst().forEach { mark.addLine(to: $0) }
                    context.stroke(mark, with: .linearGradient(Gradient(colors: [accent.opacity(0.6), accent]), startPoint: points[1], endPoint: points[2]), style: StrokeStyle(lineWidth: size * 65 / 1024, lineCap: .round, lineJoin: .round))
                    for (index, center) in points.enumerated() {
                        let radius = size * 65 / 1024
                        context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)), with: .color(accent.opacity(index == 1 ? 0.6 : 1)))
                    }
                }
            }.frame(width: size, height: size)
        }.aspectRatio(1, contentMode: .fit)
            .accessibilityElement(children: .ignore).accessibilityAddTraits(.isImage)
            .accessibilityLabel("Logo de Nodus").accessibilityIdentifier("brandLogo")
            .accessibilityValue("\(preferences.theme.title), \(colorScheme == .dark ? "Oscuro" : "Claro")")
    }
}
