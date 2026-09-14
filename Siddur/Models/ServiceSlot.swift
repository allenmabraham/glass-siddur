import Foundation

/// The service that is most likely wanted right now. The home screen turns the
/// current moment into one of these and resolves it to a node per nusach.
enum ServiceSlot: String, CaseIterable, Sendable, Identifiable {
    case shacharit, mincha, maariv
    case kabbalatShabbat, shabbatMaariv, shabbatShacharit, shabbatMusaf, shabbatMincha, havdalah
    case bedtimeShema

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shacharit: "Shacharit"
        case .mincha: "Mincha"
        case .maariv: "Maariv"
        case .kabbalatShabbat: "Kabbalat Shabbat"
        case .shabbatMaariv: "Shabbat Maariv"
        case .shabbatShacharit: "Shabbat Shacharit"
        case .shabbatMusaf: "Musaf"
        case .shabbatMincha: "Shabbat Mincha"
        case .havdalah: "Havdalah"
        case .bedtimeShema: "Bedtime Shema"
        }
    }

    var hebrewTitle: String {
        switch self {
        case .shacharit: "שחרית"
        case .mincha: "מנחה"
        case .maariv: "מעריב"
        case .kabbalatShabbat: "קבלת שבת"
        case .shabbatMaariv: "ערבית לשבת"
        case .shabbatShacharit: "שחרית לשבת"
        case .shabbatMusaf: "מוסף"
        case .shabbatMincha: "מנחה לשבת"
        case .havdalah: "הבדלה"
        case .bedtimeShema: "קריאת שמע על המיטה"
        }
    }

    var symbol: String {
        switch self {
        case .shacharit, .shabbatShacharit: "sunrise.fill"
        case .mincha, .shabbatMincha: "sun.haze.fill"
        case .maariv, .shabbatMaariv: "moon.stars.fill"
        case .kabbalatShabbat: "candle.fill"
        case .shabbatMusaf: "sun.max.fill"
        case .havdalah: "flame.fill"
        case .bedtimeShema: "bed.double.fill"
        }
    }

    /// Path of English titles from the siddur root, per nusach. Titles are matched
    /// loosely (see `SiddurNode.descendant(titled:)`).
    func path(in nusach: Nusach) -> [String] {
        switch nusach {
        case .ashkenaz:
            switch self {
            case .shacharit: ["Weekday", "Shacharit"]
            case .mincha: ["Weekday", "Minchah"]
            case .maariv: ["Weekday", "Maariv"]
            case .kabbalatShabbat: ["Shabbat", "Kabbalat Shabbat"]
            case .shabbatMaariv: ["Shabbat", "Maariv"]
            case .shabbatShacharit: ["Shabbat", "Shacharit"]
            case .shabbatMusaf: ["Shabbat", "Musaf LeShabbat"]
            case .shabbatMincha: ["Shabbat", "Minchah"]
            case .havdalah: ["Shabbat", "Havdalah"]
            case .bedtimeShema: ["Weekday", "Maariv", "Keri'at Shema al Hamita"]
            }
        case .sefard:
            switch self {
            case .shacharit: ["Weekday Shacharit"]
            case .mincha: ["Weekday Mincha"]
            case .maariv: ["Weekday Maariv"]
            case .kabbalatShabbat: ["Kabbalat Shabbat"]
            case .shabbatMaariv: ["Shabbat Eve Maariv"]
            case .shabbatShacharit: ["Shabbat Morning Services"]
            case .shabbatMusaf: ["Musaf"]
            case .shabbatMincha: ["Shabbat Mincha"]
            case .havdalah: ["Motzaei Shabbat"]
            case .bedtimeShema: ["Bedtime Shema"]
            }
        case .ari:
            switch self {
            case .shacharit, .shabbatShacharit, .shabbatMusaf: ["Shacharit"]
            case .mincha, .shabbatMincha: ["Mincha"]
            case .maariv, .shabbatMaariv, .kabbalatShabbat, .havdalah: ["Maariv"]
            case .bedtimeShema: ["Bedtime Shema"]
            }
        case .edotHaMizrach:
            switch self {
            case .shacharit: ["Weekday Shacharit"]
            case .mincha: ["Weekday Mincha"]
            case .maariv: ["Weekday Arvit"]
            case .kabbalatShabbat: ["Kabbalat Shabbat"]
            case .shabbatMaariv: ["Shabbat Arvit"]
            case .shabbatShacharit: ["Shabbat Shacharit"]
            case .shabbatMusaf: ["Shabbat Mussaf"]
            case .shabbatMincha: ["Shabbat Mincha"]
            case .havdalah: ["Havdalah"]
            case .bedtimeShema: ["Bedtime Shema"]
            }
        }
    }
}
