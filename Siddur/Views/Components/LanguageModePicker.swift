import SwiftUI

/// Glass segmented control: עברית · Both · English.
struct LanguageModePicker: View {
    @Binding var mode: LanguageMode
    var compact = false

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(LanguageMode.allCases) { candidate in
                    Button {
                        withAnimation(.snappy(duration: 0.28)) { mode = candidate }
                    } label: {
                        Group {
                            if compact {
                                Image(systemName: candidate.symbol)
                            } else {
                                Label(candidate.label, systemImage: candidate.symbol)
                                    .labelStyle(.titleOnly)
                            }
                        }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, compact ? 12 : 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: compact ? nil : .infinity)
                        .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(mode == candidate ? Color.white : Color.primary)
                    .background { if mode == candidate { Capsule().fill(Color.brand) } }
                    .glassEffect(mode == candidate ? .regular.tint(Color.brand).interactive() : .regular.interactive(), in: .capsule)
                    .accessibilityLabel(candidate == .hebrew ? "Hebrew only" : candidate == .english ? "English only" : "Hebrew and English")
                    .accessibilityAddTraits(mode == candidate ? .isSelected : [])
                }
            }
        }
        .sensoryFeedback(.selection, trigger: mode)
    }
}

/// Glass chip row for choosing a nusach.
struct NusachPicker: View {
    @Binding var nusach: Nusach

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Nusach.allCases) { candidate in
                    Button {
                        withAnimation(.snappy(duration: 0.28)) { nusach = candidate }
                    } label: {
                        VStack(spacing: 2) {
                            Text(candidate.displayName)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                                .allowsTightening(true)
                            Text(candidate.hebrewName)
                                .font(.caption2)
                                .opacity(0.8)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 9)
                        .frame(maxWidth: .infinity)
                        .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(nusach == candidate ? Color.white : Color.primary)
                    .background { if nusach == candidate { Capsule().fill(Color.brand) } }
                    .glassEffect(nusach == candidate ? .regular.tint(Color.brand).interactive() : .regular.interactive(), in: .capsule)
                    .accessibilityAddTraits(nusach == candidate ? .isSelected : [])
                }
            }
        }
        .sensoryFeedback(.selection, trigger: nusach)
    }
}
