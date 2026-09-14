import SwiftUI

/// One paragraph laid out per the current language mode: Hebrew on the right,
/// English on the left, aligned at the top so the two columns track each other.
///
/// Sync: every paragraph is one row, so its translation always sits beside it.
/// Tapping a paragraph highlights the pair; in a single-language mode a tap
/// reveals the other language beneath it for just that paragraph.
struct ParagraphRow: View {
    let paragraph: PrayerParagraph
    let nusach: Nusach
    var rowID: String = ""
    @Binding var selection: String?
    @Environment(ReadingSettings.self) private var settings
    @Environment(\.readerWidth) private var availableWidth

    init(paragraph: PrayerParagraph, nusach: Nusach, rowID: String = "", selection: Binding<String?> = .constant(nil)) {
        self.paragraph = paragraph
        self.nusach = nusach
        self.rowID = rowID
        self._selection = selection
    }

    private var mode: LanguageMode {
        // A nusach without an English version always reads as Hebrew.
        nusach.hasEnglish ? settings.languageMode : .hebrew
    }

    private var isSelected: Bool { !rowID.isEmpty && selection == rowID }
    private var canReveal: Bool { paragraph.hasHebrew && paragraph.hasEnglish && nusach.hasEnglish }

    var body: some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.brand.opacity(isSelected ? 0.12 : 0))
            }
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.brand)
                        .frame(width: 3)
                        .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, -10)
            .contentShape(.rect)
            .onTapGesture {
                guard !rowID.isEmpty else { return }
                withAnimation(.snappy(duration: 0.25)) {
                    selection = isSelected ? nil : rowID
                }
            }
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var content: some View {
        switch mode {
        case .hebrew:
            VStack(alignment: .trailing, spacing: 10) {
                hebrewColumn.frame(maxWidth: .infinity, alignment: .trailing)
                if isSelected && canReveal {
                    revealed(englishColumn)
                }
            }
        case .english:
            VStack(alignment: .leading, spacing: 10) {
                if paragraph.hasEnglish {
                    englishColumn.frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    hebrewColumn.frame(maxWidth: .infinity, alignment: .trailing)
                }
                if isSelected && canReveal {
                    revealed(hebrewColumn)
                }
            }
        case .bilingual:
            switch settings.resolvedLayout(forWidth: availableWidth) {
            case .sideBySide, .automatic:
                HStack(alignment: .top, spacing: 18) {
                    englishColumn.frame(maxWidth: .infinity, alignment: .topLeading)
                    hebrewColumn.frame(maxWidth: .infinity, alignment: .topTrailing)
                }
                .environment(\.layoutDirection, .leftToRight)
            case .stacked:
                VStack(alignment: .trailing, spacing: 8) {
                    hebrewColumn.frame(maxWidth: .infinity, alignment: .trailing)
                    englishColumn.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// The other language, shown inline under a tapped paragraph.
    private func revealed<V: View>(_ column: V) -> some View {
        column
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.thinMaterial, in: .rect(cornerRadius: 12, style: .continuous))
            .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var isInstruction: Bool {
        StyledText.isInstruction(paragraph.hasHebrew ? paragraph.hebrewHTML : paragraph.englishHTML)
    }

    @ViewBuilder private var hebrewColumn: some View {
        if paragraph.hasHebrew {
            StyledText.hebrew(paragraph.hebrewHTML, settings: settings)
                .lineSpacing(settings.hebrewLineSpacing)
                .multilineTextAlignment(isInstruction ? .center : .leading)
                .frame(maxWidth: .infinity, alignment: isInstruction ? .center : .leading)
                .environment(\.layoutDirection, .rightToLeft)
        } else {
            Color.clear.frame(height: 1)
        }
    }

    @ViewBuilder private var englishColumn: some View {
        if paragraph.hasEnglish {
            StyledText.english(paragraph.englishHTML, settings: settings)
                .lineSpacing(settings.englishLineSpacing)
                .multilineTextAlignment(isInstruction ? .center : .leading)
                .frame(maxWidth: .infinity, alignment: isInstruction ? .center : .leading)
                .environment(\.layoutDirection, .leftToRight)
        } else {
            Color.clear.frame(height: 1)
        }
    }
}

/// Width of the reading column, set by `ReaderView`, used to decide side-by-side vs stacked.
private struct ReaderWidthKey: EnvironmentKey { static let defaultValue: CGFloat = 400 }
extension EnvironmentValues {
    var readerWidth: CGFloat {
        get { self[ReaderWidthKey.self] }
        set { self[ReaderWidthKey.self] = newValue }
    }
}
