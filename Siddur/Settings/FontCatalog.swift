import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// A selectable typeface. Either a system design or a font family shipped with iOS.
struct FontChoice: Codable, Hashable, Identifiable, Sendable {
    enum Kind: Codable, Hashable, Sendable {
        case system(design: SystemDesign)
        case named(String)
    }
    enum SystemDesign: String, Codable, Hashable, Sendable {
        case standard, serif, rounded, monospaced
        var design: Font.Design {
            switch self {
            case .standard: .default
            case .serif: .serif
            case .rounded: .rounded
            case .monospaced: .monospaced
            }
        }
    }

    let id: String
    let displayName: String
    let kind: Kind
    /// PostScript name of the bold face, when the family ships one we can name directly.
    var boldName: String? = nil
    /// Short note shown in the picker ("Traditional siddur face").
    var note: String? = nil

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch kind {
        case .system(let design): .system(size: size, weight: weight, design: design.design)
        case .named(let name): .custom(name, size: size)
        }
    }

    /// Font for bold runs. Falls back to SwiftUI's synthesized bold when no bold face is named.
    func boldFont(size: CGFloat) -> Font? {
        guard let boldName else { return nil }
        return .custom(boldName, size: size)
    }

    var isAvailable: Bool {
        switch kind {
        case .system: return true
        case .named(let name):
            #if canImport(UIKit)
            return UIFont(name: name, size: 12) != nil
            #elseif canImport(AppKit)
            return NSFont(name: name, size: 12) != nil
            #else
            return true
            #endif
        }
    }
}

enum FontCatalog {
    /// Bundled Open Font License siddur faces first, then iOS fonts with Hebrew glyphs.
    static let hebrew: [FontChoice] = [
        FontChoice(id: "he.frank", displayName: "Frank Ruhl", kind: .named("FrankRuhlLibre-Regular"), boldName: "FrankRuhlLibre-Regular_Bold", note: "Traditional siddur face"),
        FontChoice(id: "he.david", displayName: "David", kind: .named("DavidLibre-Regular"), boldName: "DavidLibre-Bold", note: "Classic Israeli serif"),
        FontChoice(id: "he.noto", displayName: "Noto Serif", kind: .named("NotoSerifHebrew-Regular"), boldName: "NotoSerifHebrew-Regular_Bold"),
        FontChoice(id: "he.system", displayName: "SF Hebrew", kind: .system(design: .standard), note: "Modern"),
        FontChoice(id: "he.arial", displayName: "Arial Hebrew", kind: .named("ArialHebrew")),
        FontChoice(id: "he.arialScholar", displayName: "Arial Hebrew Scholar", kind: .named("ArialHebrewScholar")),
        FontChoice(id: "he.times", displayName: "Times New Roman", kind: .named("TimesNewRomanPSMT")),
        FontChoice(id: "he.courier", displayName: "Courier New", kind: .named("CourierNewPSMT")),
        FontChoice(id: "he.rounded", displayName: "SF Rounded", kind: .system(design: .rounded)),
    ].filter(\.isAvailable)

    static let english: [FontChoice] = [
        FontChoice(id: "en.newYork", displayName: "New York", kind: .system(design: .serif), note: "Book serif"),
        FontChoice(id: "en.system", displayName: "San Francisco", kind: .system(design: .standard), note: "Modern"),
        FontChoice(id: "en.rounded", displayName: "SF Rounded", kind: .system(design: .rounded)),
        FontChoice(id: "en.charter", displayName: "Charter", kind: .named("Charter-Roman")),
        FontChoice(id: "en.georgia", displayName: "Georgia", kind: .named("Georgia")),
        FontChoice(id: "en.palatino", displayName: "Palatino", kind: .named("Palatino-Roman")),
        FontChoice(id: "en.iowan", displayName: "Iowan Old Style", kind: .named("IowanOldStyle-Roman")),
        FontChoice(id: "en.baskerville", displayName: "Baskerville", kind: .named("Baskerville")),
        FontChoice(id: "en.hoefler", displayName: "Hoefler Text", kind: .named("HoeflerText-Regular")),
        FontChoice(id: "en.avenir", displayName: "Avenir Next", kind: .named("AvenirNext-Regular")),
        FontChoice(id: "en.times", displayName: "Times New Roman", kind: .named("TimesNewRomanPSMT")),
    ].filter(\.isAvailable)

    static func hebrew(id: String) -> FontChoice { hebrew.first { $0.id == id } ?? hebrew[0] }
    static func english(id: String) -> FontChoice { english.first { $0.id == id } ?? english[0] }
}
