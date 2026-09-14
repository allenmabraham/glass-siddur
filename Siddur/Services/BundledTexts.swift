import Foundation

/// Every prayer of every siddur ships inside the app (Resources/Texts/<nusach>-texts.json,
/// produced by Tools/fetch-texts.js), so the siddur is fully usable with no
/// connection from the moment it is installed. Sefaria is only consulted for a
/// ref that is somehow missing from the bundle.
enum BundledTexts {
    nonisolated(unsafe) private static var cache: [Nusach: [String: PrayerLeafText]] = [:]
    private static let lock = NSLock()

    /// Which siddur a Sefaria ref belongs to, from its leading title.
    static func nusach(for ref: String) -> Nusach? {
        Nusach.allCases.first { ref == $0.sefariaTitle || ref.hasPrefix($0.sefariaTitle + ",") }
    }

    static func leaf(for ref: String) -> PrayerLeafText? {
        guard let nusach = nusach(for: ref) else { return nil }
        return texts(for: nusach)[ref]
    }

    static func contains(_ ref: String) -> Bool { leaf(for: ref) != nil }

    static func count(for nusach: Nusach) -> Int { texts(for: nusach).count }

    /// Decodes a siddur's bundle once and keeps it in memory (a few MB each).
    static func texts(for nusach: Nusach) -> [String: PrayerLeafText] {
        lock.lock(); defer { lock.unlock() }
        if let hit = cache[nusach] { return hit }
        guard let url = Bundle.main.url(forResource: "\(nusach.resourceName)-texts", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: PrayerLeafText].self, from: data)
        else {
            cache[nusach] = [:]
            return [:]
        }
        cache[nusach] = decoded
        return decoded
    }
}
