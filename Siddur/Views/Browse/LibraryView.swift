import SwiftUI

/// The Library tab: the full table of contents of the chosen nusach.
struct LibraryView: View {
    @Environment(ReadingSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        VStack(spacing: 0) {
            NusachPicker(nusach: $settings.nusach)
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
            SectionListView(nusach: settings.nusach, node: SiddurLibrary.root(for: settings.nusach))
        }
        .background(Backdrop(style: .home))
    }
}

/// The Search tab: find any prayer by English or Hebrew title.
struct SearchView: View {
    @Environment(ReadingSettings.self) private var settings
    @State private var query = ""

    private struct Hit: Identifiable {
        let node: SiddurNode
        let trail: String
        var id: String { node.id }
    }

    private var hits: [Hit] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }
        let root = SiddurLibrary.root(for: settings.nusach)
        var out: [Hit] = []
        func walk(_ n: SiddurNode, trail: [String]) {
            if n.id != "root", n.title.localizedCaseInsensitiveContains(q) || n.heTitle.contains(q) {
                out.append(Hit(node: n, trail: trail.joined(separator: " › ")))
            }
            for c in n.children ?? [] { walk(c, trail: n.id == "root" ? [] : trail + [n.title]) }
        }
        walk(root, trail: [])
        return Array(out.prefix(80))
    }

    var body: some View {
        List(hits) { hit in
            NavigationLink(value: hit.node.isLeaf ? Route.reader(settings.nusach, hit.node.id) : Route.section(settings.nusach, hit.node.id)) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(hit.node.title)
                        Spacer()
                        Text(hit.node.heTitle).foregroundStyle(.secondary)
                    }
                    if !hit.trail.isEmpty {
                        Text(hit.trail).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Backdrop(style: .home))
        .overlay {
            if hits.isEmpty {
                ContentUnavailableView(
                    query.count < 2 ? "Search \(settings.nusach.displayName)" : "No matches",
                    systemImage: "magnifyingglass",
                    description: Text(query.count < 2 ? "Find any prayer by its English or Hebrew name." : "Try another spelling, or browse the Library.")
                )
            }
        }
        .searchable(text: $query, prompt: "Prayers, psalms, blessings…")
        .navigationTitle("Search")
        .modifier(SearchSnapshotHooks(query: $query))
    }
}

/// The Saved tab: bookmarks.
struct SavedView: View {
    @Environment(UserLibrary.self) private var library
    @Environment(ReadingSettings.self) private var settings

    var body: some View {
        List {
            ForEach(library.bookmarks) { bookmark in
                NavigationLink(value: Route.reader(bookmark.nusach, bookmark.nodeID)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bookmark.title)
                            Text(bookmark.nusach.displayName).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(bookmark.heTitle)
                            .font(settings.hebrewFont.font(size: 18))
                            .foregroundStyle(.secondary)
                    }
                }
                .listRowBackground(Color.clear)
            }
            .onDelete { offsets in
                for i in offsets { library.remove(library.bookmarks[i]) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Backdrop(style: .home))
        .overlay {
            if library.bookmarks.isEmpty {
                ContentUnavailableView("No bookmarks yet", systemImage: "bookmark", description: Text("Tap the bookmark in any prayer to keep it here."))
            }
        }
        .navigationTitle("Saved")
    }
}

/// Snapshot driver hooks; compile to nothing in Release.
private struct SearchSnapshotHooks: ViewModifier {
    @Binding var query: String
    func body(content: Content) -> some View {
        #if DEBUG
        content
            .onAppear { query = SnapshotDriver.shared.searchQuery }
            .onChange(of: SnapshotDriver.shared.searchQuery) { _, q in query = q }
        #else
        content
        #endif
    }
}
