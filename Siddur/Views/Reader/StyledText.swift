import SwiftUI

/// Renders `StyledRun`s as one concatenated `Text` so a paragraph wraps as a unit
/// while opening words stay bold and instructions stay small and gray —
/// the conventions of a traditional printed siddur.
@MainActor
enum StyledText {
    static func hebrew(_ html: String, settings: ReadingSettings) -> Text {
        let runs = HTMLText.runs(from: html).map { run -> StyledRun in
            var r = run
            r.text = HebrewText.strip(run.text, vowels: !settings.showVowels, cantillation: !settings.showCantillation)
            return r
        }
        return build(runs,
                     body: settings.hebrewBodyFont,
                     small: settings.hebrewSmallFont,
                     bold: settings.hebrewFont.boldFont(size: settings.hebrewPointSize),
                     boldSmall: settings.hebrewFont.boldFont(size: settings.hebrewPointSize * 0.78))
    }

    static func english(_ html: String, settings: ReadingSettings) -> Text {
        build(HTMLText.runs(from: html),
              body: settings.englishBodyFont,
              small: settings.englishSmallFont,
              bold: settings.englishFont.boldFont(size: settings.englishPointSize),
              boldSmall: settings.englishFont.boldFont(size: settings.englishPointSize * 0.8))
    }

    /// True when a paragraph is entirely an instruction (all runs small) —
    /// rendered as a rubric rather than prayer text.
    static func isInstruction(_ html: String) -> Bool {
        let runs = HTMLText.runs(from: html)
        return !runs.isEmpty && runs.allSatisfy { $0.small || $0.text.allSatisfy(\.isWhitespace) }
    }

    private static func build(_ runs: [StyledRun], body: Font, small: Font, bold: Font?, boldSmall: Font?) -> Text {
        runs.reduce(Text(verbatim: "")) { acc, run in
            var t = Text(verbatim: run.text)
            if run.bold, let face = run.small ? boldSmall : bold {
                t = t.font(face)
            } else {
                t = t.font(run.small || run.superscript ? small : body)
                if run.bold { t = t.bold() }
            }
            if run.italic { t = t.italic() }
            if run.small { t = t.foregroundStyle(.secondary) }
            if run.superscript { t = t.baselineOffset(6) }
            return Text("\(acc)\(t)")
        }
    }
}
