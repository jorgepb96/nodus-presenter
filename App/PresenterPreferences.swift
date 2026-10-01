import PresenterCore
import SwiftUI
import UIKit

enum PresenterTheme: String, CaseIterable, Identifiable {
    case original, academic, primarySources, testimonios, databases, docencia, estudio, genealogy, prosopography, worldbuilding
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return L10n.text("Violet")
        case .academic, .primarySources: return L10n.text("Indigo")
        case .testimonios: return L10n.text("Cyan")
        case .databases: return L10n.text("Crimson")
        case .docencia: return L10n.text("Orange")
        case .estudio: return L10n.text("Teal")
        case .genealogy: return L10n.text("Amber")
        case .prosopography: return L10n.text("Blue")
        case .worldbuilding: return L10n.text("Purple")
        }
    }
    // Keep stored identifiers compatible while presenting each distinct color once.
    static var selectableCases: [Self] { allCases.filter { $0 != .primarySources } }

    // Canonical palette: nodus/shared/vaultColors.ts. Original preserves the first mobile accent.
    var hex: String {
        switch self {
        case .original: return "#8b5cf6"
        case .academic, .primarySources: return "#6366f1"
        case .estudio: return "#0f766e"
        case .genealogy: return "#ca8a04"
        case .prosopography: return "#2563eb"
        case .databases: return "#b30333"
        case .testimonios: return "#0891b2"
        case .worldbuilding: return "#7c3aed"
        case .docencia: return "#ea580c"
        }
    }
    var color: Color {
        let value = UInt64(hex.dropFirst(), radix: 16) ?? 0x8b5cf6
        let components = [Double((value >> 16) & 255), Double((value >> 8) & 255), Double(value & 255)].map { $0 / 255 }
        return Color(uiColor: UIColor { traits in
            // Keep the accent hue; lift dark accents so controls remain readable on dark surfaces.
            let lift = traits.userInterfaceStyle == .dark ? 0.32 : 0.0
            return UIColor(red: components[0] + (1 - components[0]) * lift,
                           green: components[1] + (1 - components[1]) * lift,
                           blue: components[2] + (1 - components[2]) * lift, alpha: 1)
        })
    }
}

enum PresenterAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { self == .system ? L10n.text("System") : self == .light ? L10n.text("Light") : L10n.text("Dark") }
    var colorScheme: ColorScheme? { self == .system ? nil : self == .light ? .light : .dark }
}

@MainActor final class PresenterPreferences: ObservableObject {
    private let defaults: UserDefaults
    @Published var theme: PresenterTheme { didSet { defaults.set(theme.rawValue, forKey: "presenter.theme") } }
    @Published var appearance: PresenterAppearance { didSet { defaults.set(appearance.rawValue, forKey: "presenter.appearance") } }
    @Published var slideShare: Double { didSet { defaults.set(slideShare, forKey: "presenter.slideShare") } }
    @Published var showNextSlide: Bool { didSet { defaults.set(showNextSlide, forKey: "presenter.showNextSlide") } }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if CommandLine.arguments.contains("--reset-preferences") {
            ["presenter.theme", "presenter.appearance", "presenter.slideShare", "presenter.showNextSlide"].forEach { defaults.removeObject(forKey: $0) }
        }
        let savedTheme = PresenterTheme(rawValue: defaults.string(forKey: "presenter.theme") ?? "") ?? .original
        theme = savedTheme == .primarySources ? .academic : savedTheme
        appearance = PresenterAppearance(rawValue: defaults.string(forKey: "presenter.appearance") ?? "") ?? .system
        let saved = defaults.object(forKey: "presenter.slideShare") as? Double ?? 0.42
        slideShare = saved.isFinite ? min(0.72, max(0.24, saved)) : 0.42
        showNextSlide = defaults.object(forKey: "presenter.showNextSlide") as? Bool ?? false
    }
}
