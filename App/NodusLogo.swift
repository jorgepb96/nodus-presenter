import PresenterCore
import SwiftUI
import UIKit

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
                    let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
                    let resolved = UIColor(accent).resolvedColor(with: traits)
                    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                    resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
                    context.withCGContext { cgContext in
                        NodusBrand.drawDisplay(in: cgContext, size: size,
                                              accent: .init(red: red, green: green, blue: blue))
                    }
                }
            }.frame(width: size, height: size)
        }.aspectRatio(1, contentMode: .fit)
            .accessibilityElement(children: .ignore).accessibilityAddTraits(.isImage)
            .accessibilityLabel(L10n.text("Nodus logo")).accessibilityIdentifier("brandLogo")
            .accessibilityValue("\(preferences.theme.title), \(colorScheme == .dark ? L10n.text("Dark") : L10n.text("Light"))")
    }
}
