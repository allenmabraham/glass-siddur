import SwiftUI

/// Table of contents for one section of a siddur.
struct SectionListView: View {
    let nusach: Nusach
    let node: SiddurNode

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                if node.id != "root" {
                    NavigationLink(value: Route.reader(nusach, node.id)) {
                        Label("Read all of \(node.title)", systemImage: "book")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.brandGlass)
                    .padding(.bottom, 8)
                }
                ForEach(node.children ?? []) { child in
                    NavigationLink(value: child.isLeaf ? Route.reader(nusach, child.id) : Route.section(nusach, child.id)) {
                        SectionRow(node: child)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(Backdrop(style: .home))
        .navigationTitle(node.id == "root" ? nusach.displayName : node.title)
        .navigationSubtitle(node.id == "root" ? nusach.hebrewName : node.heTitle)
    }
}

struct SectionRow: View {
    let node: SiddurNode
    @Environment(ReadingSettings.self) private var settings

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(node.title).font(.body.weight(.medium))
                if !node.isLeaf {
                    Text("\(node.leafCount) \(node.leafCount == 1 ? "prayer" : "prayers")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(node.heTitle)
                .font(settings.hebrewFont.font(size: 18))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Image(systemName: node.isLeaf ? "text.alignright" : "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.thinMaterial, in: .rect(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.3), lineWidth: 0.6)
                .blendMode(.plusLighter)
        }
        .contentShape(.rect)
    }
}
