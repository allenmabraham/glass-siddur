import Foundation

/// A single paragraph with its Hebrew and English (either may be empty when a
/// version is missing that segment). Text is Sefaria HTML; see `HTMLText`.
struct PrayerParagraph: Identifiable, Hashable, Sendable, Codable {
    let index: Int
    let hebrewHTML: String
    let englishHTML: String

    var id: Int { index }
    var hasHebrew: Bool { !hebrewHTML.isEmpty }
    var hasEnglish: Bool { !englishHTML.isEmpty }
}

/// The text of one leaf (one prayer) in a siddur.
struct PrayerLeafText: Hashable, Sendable, Codable {
    let ref: String
    let heRef: String
    let title: String
    let heTitle: String
    let hebrewVersionTitle: String?
    let englishVersionTitle: String?
    let paragraphs: [PrayerParagraph]
}

/// A prayer as displayed in the reader: the TOC node plus its loaded text.
struct PrayerBlock: Identifiable, Sendable {
    enum State: Sendable {
        case loading
        case loaded(PrayerLeafText)
        case failed(String)
    }
    let node: SiddurNode
    var state: State

    var id: String { node.id }
}
