import SwiftUI

/// A prayer heading in the style of a printed siddur — the Hebrew title centred
/// between hairlines with the English title in spaced small capitals beneath —
/// followed by its paragraphs.
struct PrayerBlockView: View {
    let block: PrayerBlock
    let nusach: Nusach
    @Binding var selection: String?
    let retry: () -> Void
    @Environment(ReadingSettings.self) private var settings

    var body: some View {
        VStack(spacing: 18) {
            heading
            switch block.state {
            case .loading:
                placeholder
            case .failed(let message):
                failure(message)
            case .loaded(let text):
                if text.paragraphs.isEmpty {
                    Text("No text available for this prayer.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: settings.hebrewPointSize * 0.9) {
                        ForEach(text.paragraphs) { paragraph in
                            ParagraphRow(paragraph: paragraph, nusach: nusach, rowID: "\(block.id)#\(paragraph.index)", selection: $selection)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 12)
    }

    private var heading: some View {
        VStack(spacing: 6) {
            HStack(spacing: 14) {
                rule
                Text(block.node.heTitle)
                    .font(settings.hebrewFont.boldFont(size: settings.hebrewPointSize * 1.15) ?? settings.hebrewFont.font(size: settings.hebrewPointSize * 1.15).weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .fixedSize()
                rule
            }
            if !block.node.title.isEmpty {
                Text(block.node.title.uppercased())
                    .font(settings.englishFont.font(size: max(11, settings.englishPointSize * 0.68)))
                    .tracking(2.2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var rule: some View {
        Rectangle()
            .fill(.secondary.opacity(0.45))
            .frame(height: 1)
            .frame(maxWidth: .infinity)
    }

    private var placeholder: some View {
        VStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.secondary.opacity(0.12))
                    .frame(height: settings.hebrewPointSize * 1.1)
                    .frame(maxWidth: .infinity)
                    .padding(.leading, CGFloat(i) * 24)
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityLabel("Loading")
    }

    private func failure(_ message: String) -> some View {
        VStack(spacing: 10) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try again", systemImage: "arrow.clockwise", action: retry)
                .buttonStyle(.glass)
        }
        .frame(maxWidth: .infinity)
    }
}
