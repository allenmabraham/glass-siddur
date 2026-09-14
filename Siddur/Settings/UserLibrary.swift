import Foundation
import Observation

/// A saved place in a siddur.
struct Bookmark: Codable, Hashable, Identifiable, Sendable {
    let nusach: Nusach
    let nodeID: String
    let title: String
    let heTitle: String
    let created: Date
    var id: String { "\(nusach.rawValue)|\(nodeID)" }
}

/// Bookmarks and the "continue reading" pointer. Persisted in UserDefaults.
@MainActor
@Observable
final class UserLibrary {
    static let shared = UserLibrary()

    private(set) var bookmarks: [Bookmark] = []
    private(set) var lastRead: Bookmark?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "bookmarks"), let list = try? JSONDecoder().decode([Bookmark].self, from: data) {
            bookmarks = list
        }
        if let data = defaults.data(forKey: "lastRead"), let last = try? JSONDecoder().decode(Bookmark.self, from: data) {
            lastRead = last
        }
    }

    func isBookmarked(_ node: SiddurNode, in nusach: Nusach) -> Bool {
        bookmarks.contains { $0.nusach == nusach && $0.nodeID == node.id }
    }

    func toggleBookmark(_ node: SiddurNode, in nusach: Nusach) {
        if let idx = bookmarks.firstIndex(where: { $0.nusach == nusach && $0.nodeID == node.id }) {
            bookmarks.remove(at: idx)
        } else {
            bookmarks.insert(Bookmark(nusach: nusach, nodeID: node.id, title: node.title, heTitle: node.heTitle, created: .now), at: 0)
        }
        persist()
    }

    func remove(_ bookmark: Bookmark) {
        bookmarks.removeAll { $0.id == bookmark.id }
        persist()
    }

    func markRead(_ node: SiddurNode, in nusach: Nusach) {
        lastRead = Bookmark(nusach: nusach, nodeID: node.id, title: node.title, heTitle: node.heTitle, created: .now)
        if let data = try? JSONEncoder().encode(lastRead) { defaults.set(data, forKey: "lastRead") }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(bookmarks) { defaults.set(data, forKey: "bookmarks") }
    }
}
