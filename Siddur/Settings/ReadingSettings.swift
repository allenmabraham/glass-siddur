import SwiftUI
import Observation

enum LanguageMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case hebrew, bilingual, english
    var id: String { rawValue }
    var label: String {
        switch self {
        case .hebrew: "עברית"
        case .bilingual: "Both"
        case .english: "English"
        }
    }
    var symbol: String {
        switch self {
        case .hebrew: "character.textbox.he"
        case .bilingual: "rectangle.split.2x1"
        case .english: "character.textbox"
        }
    }
}

enum BilingualLayout: String, CaseIterable, Codable, Identifiable, Sendable {
    case automatic, sideBySide, stacked
    var id: String { rawValue }
    var label: String {
        switch self {
        case .automatic: "Auto"
        case .sideBySide: "Side by side"
        case .stacked: "Stacked"
        }
    }
}

enum ReaderTheme: String, CaseIterable, Codable, Identifiable, Sendable {
    case system, light, sepia, dark
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

/// Everything about how prayer text is displayed. Persisted in UserDefaults.
@MainActor
@Observable
final class ReadingSettings {
    static let shared = ReadingSettings()

    var languageMode: LanguageMode { didSet { save("languageMode", languageMode.rawValue) } }
    var bilingualLayout: BilingualLayout { didSet { save("bilingualLayout", bilingualLayout.rawValue) } }
    var theme: ReaderTheme { didSet { save("theme", theme.rawValue) } }
    var nusach: Nusach { didSet { save("nusach", nusach.rawValue) } }

    /// Multiplier on the base type size. 1.0 ≈ 20pt Hebrew / 17pt English.
    var fontScale: Double { didSet { save("fontScale", fontScale) } }
    static let fontScaleRange: ClosedRange<Double> = 0.6...2.6
    var lineSpacing: Double { didSet { save("lineSpacing", lineSpacing) } }
    var hebrewFontID: String { didSet { save("hebrewFontID", hebrewFontID) } }
    var englishFontID: String { didSet { save("englishFontID", englishFontID) } }
    var showVowels: Bool { didSet { save("showVowels", showVowels) } }
    var showCantillation: Bool { didSet { save("showCantillation", showCantillation) } }
    var keepScreenAwake: Bool { didSet { save("keepScreenAwake", keepScreenAwake) } }
    var useLocation: Bool { didSet { save("useLocation", useLocation) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        languageMode = LanguageMode(rawValue: defaults.string(forKey: "languageMode") ?? "") ?? .bilingual
        bilingualLayout = BilingualLayout(rawValue: defaults.string(forKey: "bilingualLayout") ?? "") ?? .automatic
        theme = ReaderTheme(rawValue: defaults.string(forKey: "theme") ?? "") ?? .system
        nusach = Nusach(rawValue: defaults.string(forKey: "nusach") ?? "") ?? .ashkenaz
        fontScale = (defaults.object(forKey: "fontScale") as? Double ?? 1.0).clamped(to: Self.fontScaleRange)
        lineSpacing = defaults.object(forKey: "lineSpacing") as? Double ?? 1.0
        hebrewFontID = defaults.string(forKey: "hebrewFontID") ?? FontCatalog.hebrew[0].id
        englishFontID = defaults.string(forKey: "englishFontID") ?? FontCatalog.english[0].id
        showVowels = defaults.object(forKey: "showVowels") as? Bool ?? true
        showCantillation = defaults.object(forKey: "showCantillation") as? Bool ?? true
        keepScreenAwake = defaults.object(forKey: "keepScreenAwake") as? Bool ?? true
        useLocation = defaults.object(forKey: "useLocation") as? Bool ?? false
    }

    private func save(_ key: String, _ value: Any) { defaults.set(value, forKey: key) }

    // MARK: - Derived typography

    var hebrewFont: FontChoice { FontCatalog.hebrew(id: hebrewFontID) }
    var englishFont: FontChoice { FontCatalog.english(id: englishFontID) }

    var hebrewPointSize: CGFloat { 21 * fontScale }
    var englishPointSize: CGFloat { 17 * fontScale }

    var hebrewBodyFont: Font { hebrewFont.font(size: hebrewPointSize) }
    var hebrewSmallFont: Font { hebrewFont.font(size: hebrewPointSize * 0.78) }
    var englishBodyFont: Font { englishFont.font(size: englishPointSize) }
    var englishSmallFont: Font { englishFont.font(size: englishPointSize * 0.8) }

    /// Side-by-side columns need roughly eight Hebrew glyphs per line to read well;
    /// below that (large type on a phone) the pair stacks, Hebrew above English.
    func resolvedLayout(forWidth width: CGFloat) -> BilingualLayout {
        switch bilingualLayout {
        case .sideBySide, .stacked: return bilingualLayout
        case .automatic:
            let column = (width - 18) / 2
            return column >= hebrewPointSize * 8 ? .sideBySide : .stacked
        }
    }

    var hebrewLineSpacing: CGFloat { hebrewPointSize * 0.28 * lineSpacing }
    var englishLineSpacing: CGFloat { englishPointSize * 0.30 * lineSpacing }

    func setFontScale(_ value: Double) { fontScale = value.clamped(to: Self.fontScaleRange) }
    func increaseFont() { setFontScale(fontScale + 0.1) }
    func decreaseFont() { setFontScale(fontScale - 0.1) }

    func resetTypography() {
        fontScale = 1.0
        lineSpacing = 1.0
        hebrewFontID = FontCatalog.hebrew[0].id
        englishFontID = FontCatalog.english[0].id
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
