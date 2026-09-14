import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension View {
    /// Inline (small) navigation title on iOS; no-op elsewhere.
    @ViewBuilder
    func inlineTitle() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    /// Hides the tab bar while reading so the page is uninterrupted.
    @ViewBuilder
    func hidesTabBar() -> some View {
        #if os(iOS)
        self.toolbarVisibility(.hidden, for: .tabBar)
        #else
        self
        #endif
    }

    /// Keeps the screen on while a prayer is open.
    @ViewBuilder
    func keepsScreenAwake(_ enabled: Bool) -> some View {
        #if os(iOS)
        self.onAppear { UIApplication.shared.isIdleTimerDisabled = enabled }
            .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
            .onChange(of: enabled) { _, newValue in UIApplication.shared.isIdleTimerDisabled = newValue }
        #else
        self
        #endif
    }
}

extension ToolbarItemPlacement {
    /// Bottom floating bar on iPhone; primary action area elsewhere.
    static var readerBar: ToolbarItemPlacement {
        #if os(iOS)
        .bottomBar
        #else
        .primaryAction
        #endif
    }
}
