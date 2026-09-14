import SwiftUI

enum AppTab: Hashable { case today, library, saved, search }

struct RootView: View {
    @State private var tab: AppTab = .today
    @State private var todayPath: [Route] = []
    @State private var libraryPath: [Route] = []
    @State private var savedPath: [Route] = []
    @State private var searchPath: [Route] = []

    /// Bindings handed to the snapshot driver.
    struct Controls {
        var tab: Binding<AppTab>
        var todayPath: Binding<[Route]>
        var libraryPath: Binding<[Route]>
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab("Today", systemImage: "sun.horizon", value: .today) {
                NavigationStack(path: $todayPath) {
                    HomeView()
                        .navigationDestination(for: Route.self) { RouteView(route: $0) }
                }
            }
            Tab("Library", systemImage: "books.vertical", value: .library) {
                NavigationStack(path: $libraryPath) {
                    LibraryView()
                        .navigationDestination(for: Route.self) { RouteView(route: $0) }
                }
            }
            Tab("Saved", systemImage: "bookmark", value: .saved) {
                NavigationStack(path: $savedPath) {
                    SavedView()
                        .navigationDestination(for: Route.self) { RouteView(route: $0) }
                }
            }
            Tab(value: .search, role: .search) {
                NavigationStack(path: $searchPath) {
                    SearchView()
                        .navigationDestination(for: Route.self) { RouteView(route: $0) }
                }
            }
        }
        .modifier(TabBarBehavior())
        #if DEBUG
        .task {
            let driver = SnapshotDriver.shared
            guard driver.isEnabled else { return }
            await driver.run(controls: Controls(tab: $tab, todayPath: $todayPath, libraryPath: $libraryPath))
        }
        #endif
    }
}

private struct TabBarBehavior: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.tabBarMinimizeBehavior(.onScrollDown)
        #else
        content
        #endif
    }
}
