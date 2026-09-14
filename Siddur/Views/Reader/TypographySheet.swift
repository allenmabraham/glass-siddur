import SwiftUI

/// Text size, fonts, spacing, layout and nikud controls with a live preview.
struct TypographySheet: View {
    @Environment(ReadingSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    private let previewHebrew = "<b>מוֹדֶה אֲנִי</b> לְפָנֶֽיךָ מֶֽלֶךְ חַי וְקַיָּם, שֶׁהֶחֱזַֽרְתָּ בִּי נִשְׁמָתִי בְּחֶמְלָה, רַבָּה אֱמוּנָתֶֽךָ."
    private let previewEnglish = "<b>I give thanks</b> before You, living and eternal King, for You have returned my soul within me with compassion; abundant is Your faithfulness."

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    preview
                    sizeControls
                    fontPicker(title: "Hebrew typeface", sample: "אבג", choices: FontCatalog.hebrew, selection: $settings.hebrewFontID)
                    fontPicker(title: "English typeface", sample: "Aa", choices: FontCatalog.english, selection: $settings.englishFontID)
                    layoutControls
                    hebrewControls
                }
                .padding(20)
            }
            .background(Backdrop(style: .reader))
            .navigationTitle("Text")
            .inlineTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") { withAnimation { settings.resetTypography() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.glassProminent).tint(.brand)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var preview: some View {
        SurfaceCard(padding: 18) {
            ParagraphRow(paragraph: PrayerParagraph(index: 0, hebrewHTML: previewHebrew, englishHTML: previewEnglish), nusach: .ashkenaz)
                .environment(\.readerWidth, 340)
        }
        .animation(.snappy, value: settings.fontScale)
    }

    private var sizeControls: some View {
        @Bindable var settings = settings
        return SurfaceCard(padding: 16) {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    Button { settings.decreaseFont() } label: {
                        Text("A").font(.system(size: 15, weight: .semibold, design: .serif)).frame(width: 28, height: 28)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Smaller text")
                    Slider(value: $settings.fontScale, in: ReadingSettings.fontScaleRange, step: 0.05).accessibilityLabel("Text size")
                    Button { settings.increaseFont() } label: {
                        Text("A").font(.system(size: 24, weight: .semibold, design: .serif)).frame(width: 28, height: 28)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("Larger text")
                }
                HStack {
                    Label("Line spacing", systemImage: "text.line.first.and.arrowtriangle.forward")
                        .font(.subheadline)
                    Slider(value: $settings.lineSpacing, in: 0.5...2.0, step: 0.1).accessibilityLabel("Line spacing")
                }
                Text("Tips: pinch the page to resize text. Tap any paragraph to highlight it with its translation; in Hebrew-only mode a tap reveals the English underneath.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func fontPicker(title: String, sample: String, choices: [FontChoice], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.subheadline.weight(.semibold)).padding(.horizontal, 4)
            ScrollView(.horizontal) {
                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(choices) { choice in
                            let selected = selection.wrappedValue == choice.id
                            Button {
                                withAnimation(.snappy) { selection.wrappedValue = choice.id }
                            } label: {
                                VStack(spacing: 4) {
                                    Text(sample)
                                        .font(choice.font(size: 26))
                                        .frame(height: 34)
                                    Text(choice.displayName)
                                        .font(.caption2.weight(.medium))
                                        .lineLimit(1)
                                    if let note = choice.note {
                                        Text(note).font(.system(size: 9)).opacity(0.7).lineLimit(1)
                                    }
                                }
                                .frame(width: 104)
                                .padding(.vertical, 10)
                                .contentShape(.rect(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(selected ? Color.white : Color.primary)
                            .background { if selected { RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.brand) } }
                            .glassEffect(selected ? .regular.tint(Color.brand).interactive() : .regular.interactive(), in: .rect(cornerRadius: 18, style: .continuous))
                            .accessibilityAddTraits(selected ? .isSelected : [])
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var layoutControls: some View {
        @Bindable var settings = settings
        return SurfaceCard(padding: 16) {
            VStack(spacing: 14) {
                LanguageModePicker(mode: $settings.languageMode)
                if settings.languageMode == .bilingual {
                    Picker("Layout", selection: $settings.bilingualLayout) {
                        ForEach(BilingualLayout.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Picker("Appearance", selection: $settings.theme) {
                    ForEach(ReaderTheme.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var hebrewControls: some View {
        @Bindable var settings = settings
        return SurfaceCard(padding: 16) {
            VStack(spacing: 10) {
                Toggle(isOn: $settings.showVowels) { Label("Vowels (nikud)", systemImage: "textformat.abc.dottedunderline") }
                Toggle(isOn: $settings.showCantillation) { Label("Cantillation (ta'amim)", systemImage: "music.note") }
            }
            .font(.subheadline)
        }
    }
}
