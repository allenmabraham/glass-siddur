import SwiftUI

extension Color {
    /// App accent: a slate blue that reads well on both the light parchment and
    /// the dark indigo backdrops. Mirrors AccentColor in the asset catalog.
    /// Kept as a plain color: a dynamic platform color here breaks scene-level tinting.
    static let brand = Color(red: 0.30, green: 0.47, blue: 0.72)
}

/// Prominent call-to-action: brand-filled capsule under interactive glass.
/// Used instead of `.glassProminent` so the fill is guaranteed on every platform.
struct BrandGlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Capsule().fill(Color.brand))
            .glassEffect(.regular.tint(Color.brand).interactive(), in: .capsule)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == BrandGlassButtonStyle {
    static var brandGlass: BrandGlassButtonStyle { BrandGlassButtonStyle() }
}
