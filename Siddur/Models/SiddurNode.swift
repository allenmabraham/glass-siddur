import Foundation

/// One node of a siddur's table of contents. Mirrors the compact JSON produced
/// from Sefaria's index (`Resources/Indices/*.json`).
struct SiddurNode: Codable, Identifiable, Hashable, Sendable {
    /// Positional id ("1.4.6"). Unique within one siddur even when titles repeat.
    let id: String
    let title: String
    let heTitle: String
    /// Full Sefaria ref, e.g. "Siddur Ashkenaz, Weekday, Shacharit, Amidah, Patriarchs".
    let ref: String
    let heRef: String
    let children: [SiddurNode]?
    /// Text depth for leaves (1 = list of paragraphs, 2 = chapters of paragraphs).
    let depth: Int?

    var isLeaf: Bool { children == nil }

    /// Every leaf under this node in reading order (or the node itself if it is a leaf).
    var leaves: [SiddurNode] {
        guard let children else { return [self] }
        return children.flatMap(\.leaves)
    }

    var leafCount: Int { leaves.count }

    /// Depth-first search for a node by id.
    func node(withID target: String) -> SiddurNode? {
        if id == target { return self }
        for child in children ?? [] {
            if let hit = child.node(withID: target) { return hit }
        }
        return nil
    }

    /// Finds a descendant by walking a path of English titles (case-insensitive,
    /// whitespace-insensitive so minor Sefaria title edits don't break lookups).
    func descendant(titled path: [String]) -> SiddurNode? {
        var current = self
        for step in path {
            let wanted = SiddurNode.normalize(step)
            guard let next = current.children?.first(where: { SiddurNode.normalize($0.title) == wanted }) else {
                return nil
            }
            current = next
        }
        return current
    }

    /// Ancestor chain (excluding root) that leads to the node with the given id.
    func trail(to target: String) -> [SiddurNode]? {
        if id == target { return [] }
        for child in children ?? [] {
            if let rest = child.trail(to: target) { return [child] + rest }
        }
        return nil
    }

    static func normalize(_ s: String) -> String {
        s.lowercased().filter { !$0.isWhitespace && $0 != "'" && $0 != "’" }
    }
}
