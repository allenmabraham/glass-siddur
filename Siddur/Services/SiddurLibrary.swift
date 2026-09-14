import Foundation

/// Loads the bundled table of contents for each nusach.
enum SiddurLibrary {
    nonisolated(unsafe) private static var cache: [Nusach: SiddurNode] = [:]
    private static let lock = NSLock()

    static func root(for nusach: Nusach) -> SiddurNode {
        lock.lock(); defer { lock.unlock() }
        if let hit = cache[nusach] { return hit }
        guard let url = Bundle.main.url(forResource: nusach.resourceName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let node = try? JSONDecoder().decode(SiddurNode.self, from: data)
        else {
            let empty = SiddurNode(id: "root", title: nusach.sefariaTitle, heTitle: "", ref: nusach.sefariaTitle, heRef: "", children: [], depth: nil)
            cache[nusach] = empty
            return empty
        }
        cache[nusach] = node
        return node
    }

    static func node(for slot: ServiceSlot, in nusach: Nusach) -> SiddurNode? {
        root(for: nusach).descendant(titled: slot.path(in: nusach))
    }
}
