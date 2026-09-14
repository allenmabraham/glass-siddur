import Foundation

/// The three complete siddurim available on Sefaria.
enum Nusach: String, CaseIterable, Codable, Identifiable, Sendable {
    case ashkenaz
    case sefard
    case ari
    case edotHaMizrach

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ashkenaz: "Ashkenaz"
        case .sefard: "Sefard"
        case .ari: "Ari"
        case .edotHaMizrach: "Edot HaMizrach"
        }
    }

    var hebrewName: String {
        switch self {
        case .ashkenaz: "אשכנז"
        case .sefard: "ספרד"
        case .ari: "אר״י"
        case .edotHaMizrach: "עדות המזרח"
        }
    }

    var subtitle: String {
        switch self {
        case .ashkenaz: "Central & Western European rite"
        case .sefard: "Chassidic rite"
        case .ari: "Chabad rite · Hebrew only · weekday"
        case .edotHaMizrach: "Sephardic & Mizrachi rite"
        }
    }

    /// Sefaria has no English translation for the Chabad siddur.
    var hasEnglish: Bool { self != .ari }

    /// Only the weekday services exist on Sefaria for Nusach Ari.
    var hasShabbat: Bool { self != .ari }

    /// Bundled compact index resource (see Resources/Indices).
    var resourceName: String { rawValue }

    /// Sefaria index title, e.g. "Siddur Ashkenaz".
    var sefariaTitle: String {
        switch self {
        case .ashkenaz: "Siddur Ashkenaz"
        case .sefard: "Siddur Sefard"
        case .ari: "Weekday Siddur Chabad"
        case .edotHaMizrach: "Siddur Edot HaMizrach"
        }
    }

    var symbol: String {
        switch self {
        case .ashkenaz: "building.columns"
        case .sefard: "flame"
        case .ari: "crown"
        case .edotHaMizrach: "sun.max"
        }
    }
}
