import Foundation

enum HebrewText {
    /// Hebrew vowel points (nikud), U+05B0–U+05BD, U+05BF, U+05C1–U+05C2, U+05C4–U+05C5, U+05C7.
    private static let nikud: Set<Unicode.Scalar> = {
        var s = Set<Unicode.Scalar>()
        for v in 0x05B0...0x05BD { s.insert(Unicode.Scalar(UInt32(v))!) }
        s.insert(Unicode.Scalar(0x05BF)!)
        s.insert(Unicode.Scalar(0x05C1)!); s.insert(Unicode.Scalar(0x05C2)!)
        s.insert(Unicode.Scalar(0x05C4)!); s.insert(Unicode.Scalar(0x05C5)!)
        s.insert(Unicode.Scalar(0x05C7)!)
        return s
    }()

    /// Cantillation marks (ta'amim), U+0591–U+05AF plus meteg U+05BD handled with nikud.
    private static let cantillation: Set<Unicode.Scalar> = {
        var s = Set<Unicode.Scalar>()
        for v in 0x0591...0x05AF { s.insert(Unicode.Scalar(UInt32(v))!) }
        return s
    }()

    static func strip(_ text: String, vowels: Bool, cantillation stripCantillation: Bool) -> String {
        guard vowels || stripCantillation else { return text }
        var out = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            if vowels && nikud.contains(scalar) { continue }
            if stripCantillation && cantillation.contains(scalar) { continue }
            out.append(scalar)
        }
        return String(out)
    }

    static func containsHebrew(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0590...0x05FF).contains(Int($0.value)) }
    }
}
