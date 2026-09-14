import SwiftUI

enum Route: Hashable {
    case section(Nusach, String)
    case reader(Nusach, String)
}

/// Resolves a route to its screen.
struct RouteView: View {
    let route: Route

    var body: some View {
        switch route {
        case .section(let nusach, let id):
            if let node = SiddurLibrary.root(for: nusach).node(withID: id) {
                SectionListView(nusach: nusach, node: node)
            } else {
                missing
            }
        case .reader(let nusach, let id):
            if let node = SiddurLibrary.root(for: nusach).node(withID: id) {
                ReaderView(nusach: nusach, node: node)
            } else {
                missing
            }
        }
    }

    private var missing: some View {
        ContentUnavailableView("Not found", systemImage: "book.closed", description: Text("This prayer is no longer in the table of contents."))
    }
}
