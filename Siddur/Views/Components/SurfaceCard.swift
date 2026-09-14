import SwiftUI

/// A translucent content surface. Liquid Glass is reserved for floating controls
/// (per Apple's guidance); content sits on a quieter material so text stays legible.
struct SurfaceCard<Content: View>: View {
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 28
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(.thinMaterial, in: .rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 0.6)
                    .blendMode(.plusLighter)
            }
            .shadow(color: .black.opacity(0.06), radius: 18, y: 8)
    }
}

/// Section heading used on Home and Browse.
struct SectionHeading: View {
    let title: String
    var hebrew: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
            Spacer()
            if let hebrew {
                Text(hebrew)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }
}
