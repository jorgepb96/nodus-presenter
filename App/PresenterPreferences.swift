import SwiftUI

enum PresenterTheme: String, CaseIterable, Identifiable {
    case original, academic, primarySources, testimonios, databases, docencia, estudio, genealogy, prosopography, worldbuilding
    var id: String { rawValue }
    var title: String {
        switch self {
        case .original: return "Nodus Presenter"
        case .academic: return "Académico"
        case .primarySources: return "Fuentes primarias"
        case .testimonios: return "Testimonios"
        case .databases: return "Bases de datos"
        case .docencia: return "Docencia"
        case .estudio: return "Estudio"
        case .genealogy: return "Genealogía"
        case .prosopography: return "Prosopografía"
        case .worldbuilding: return "Worldbuilding"
        }
    }
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
    var color: Color { Color(hex: hex) }
}

@MainActor final class PresenterPreferences: ObservableObject {
    private let defaults: UserDefaults
    @Published var theme: PresenterTheme { didSet { defaults.set(theme.rawValue, forKey: "presenter.theme") } }
    @Published var slideShare: Double { didSet { defaults.set(slideShare, forKey: "presenter.slideShare") } }
    @Published var showNextSlide: Bool { didSet { defaults.set(showNextSlide, forKey: "presenter.showNextSlide") } }
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if CommandLine.arguments.contains("--reset-preferences") {
            ["presenter.theme", "presenter.slideShare", "presenter.showNextSlide"].forEach { defaults.removeObject(forKey: $0) }
        }
        theme = PresenterTheme(rawValue: defaults.string(forKey: "presenter.theme") ?? "") ?? .original
        let saved = defaults.object(forKey: "presenter.slideShare") as? Double ?? 0.42
        slideShare = saved.isFinite ? min(0.72, max(0.24, saved)) : 0.42
        showNextSlide = defaults.object(forKey: "presenter.showNextSlide") as? Bool ?? false
    }
}
