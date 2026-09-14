import SwiftUI

@main
struct SiddurApp: App {
    @State private var settings = ReadingSettings.shared
    @State private var library = UserLibrary.shared
    @State private var location = LocationService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(library)
                .environment(location)
                .preferredColorScheme(settings.theme.colorScheme)
                .tint(.brand)
        }
        #if os(macOS)
        .defaultSize(width: 420, height: 880)
        #endif
    }
}

extension ReaderTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light, .sepia: .light
        case .dark: .dark
        }
    }
}
