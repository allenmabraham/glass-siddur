import Foundation
import CoreLocation

/// Answers "what is the Jewish moment right now?": Hebrew date, day type, and
/// which service is expected. Uses real sunset when a location is available and
/// a sensible fixed schedule otherwise.
struct JewishClock: Sendable {
    enum DayType: Sendable { case weekday, erevShabbat, shabbat, motzaeiShabbat }

    struct Moment: Sendable {
        let date: Date
        let hebrewDateEnglish: String
        let hebrewDateHebrew: String
        let weekdayName: String
        let dayType: DayType
        let isRoshChodesh: Bool
        let slot: ServiceSlot
        let sunset: Date?
        let sunrise: Date?
        let usedLocation: Bool
    }

    var now: Date = .now
    var location: CLLocationCoordinate2D? = nil
    var calendar: Calendar = .current

    func moment() -> Moment {
        let solar = location.map { SolarCalculator(coordinate: $0, timeZone: calendar.timeZone) }
        let sunrise = solar?.sunrise(on: now, calendar: calendar)
        let sunset = solar?.sunset(on: now, calendar: calendar)

        // Fallback schedule when no location: dawn 6:00, midday 12:30, dusk 18:30.
        let dayStart = calendar.startOfDay(for: now)
        let fallbackSunrise = calendar.date(byAdding: .minute, value: 6 * 60, to: dayStart)!
        let fallbackSunset = calendar.date(byAdding: .minute, value: 18 * 60 + 30, to: dayStart)!
        let rise = sunrise ?? fallbackSunrise
        let set = sunset ?? fallbackSunset
        let afterSunset = now >= set
        let halachicMidday = rise.addingTimeInterval(set.timeIntervalSince(rise) / 2)

        // Hebrew date (the Hebrew day begins at sunset).
        let hebrewReference = afterSunset ? calendar.date(byAdding: .day, value: 1, to: now)! : now
        var hebrew = Calendar(identifier: .hebrew)
        hebrew.timeZone = calendar.timeZone
        let hebrewDay = hebrew.component(.day, from: hebrewReference)
        let isRoshChodesh = hebrewDay == 1 || hebrewDay == 30

        let enFormatter = DateFormatter()
        enFormatter.calendar = hebrew
        enFormatter.locale = Locale(identifier: "en_US")
        enFormatter.dateFormat = "d MMMM yyyy"
        let heFormatter = DateFormatter()
        heFormatter.calendar = hebrew
        heFormatter.locale = Locale(identifier: "he_IL@calendar=hebrew;numbers=hebr")
        heFormatter.dateFormat = "d MMMM y"

        let weekday = calendar.component(.weekday, from: now)  // 1 = Sunday ... 7 = Saturday
        let dayType: DayType
        switch weekday {
        case 6: dayType = afterSunset ? .shabbat : .erevShabbat
        case 7: dayType = afterSunset ? .motzaeiShabbat : .shabbat
        default: dayType = .weekday
        }

        let hour = calendar.component(.hour, from: now)
        let slot: ServiceSlot
        switch dayType {
        case .erevShabbat:
            slot = now < halachicMidday ? .shacharit : (hour >= 16 ? .kabbalatShabbat : .mincha)
        case .shabbat:
            if weekday == 6 { slot = .shabbatMaariv }               // Friday night
            else if now < halachicMidday { slot = hour < 11 ? .shabbatShacharit : .shabbatMusaf }
            else if hour >= 23 { slot = .bedtimeShema }
            else { slot = hour >= 16 ? .shabbatMincha : .shabbatMusaf }
        case .motzaeiShabbat:
            slot = hour >= 23 ? .bedtimeShema : (now < set.addingTimeInterval(90 * 60) ? .havdalah : .maariv)
        case .weekday:
            if hour >= 23 || hour < 3 { slot = .bedtimeShema }
            else if now < halachicMidday { slot = .shacharit }
            else if afterSunset { slot = .maariv }
            else { slot = .mincha }
        }

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = .current
        weekdayFormatter.dateFormat = "EEEE"

        return Moment(
            date: now,
            hebrewDateEnglish: enFormatter.string(from: hebrewReference),
            hebrewDateHebrew: heFormatter.string(from: hebrewReference),
            weekdayName: weekdayFormatter.string(from: now),
            dayType: dayType,
            isRoshChodesh: isRoshChodesh,
            slot: slot,
            sunset: sunset,
            sunrise: sunrise,
            usedLocation: solar != nil
        )
    }
}

/// NOAA-style sunrise/sunset approximation (accurate to a minute or two).
struct SolarCalculator: Sendable {
    let coordinate: CLLocationCoordinate2D
    let timeZone: TimeZone

    func sunrise(on date: Date, calendar: Calendar) -> Date? { event(on: date, calendar: calendar, rising: true) }
    func sunset(on date: Date, calendar: Calendar) -> Date? { event(on: date, calendar: calendar, rising: false) }

    private func event(on date: Date, calendar: Calendar, rising: Bool) -> Date? {
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let lng = coordinate.longitude
        let lat = coordinate.latitude * .pi / 180
        let lngHour = lng / 15
        let t = dayOfYear + ((rising ? 6.0 : 18.0) - lngHour) / 24
        let m = (0.9856 * t) - 3.289
        var l = m + (1.916 * sin(m * .pi / 180)) + (0.020 * sin(2 * m * .pi / 180)) + 282.634
        l = l.truncatingRemainder(dividingBy: 360); if l < 0 { l += 360 }
        var ra = atan(0.91764 * tan(l * .pi / 180)) * 180 / .pi
        ra = ra.truncatingRemainder(dividingBy: 360); if ra < 0 { ra += 360 }
        let lQuadrant = floor(l / 90) * 90
        let raQuadrant = floor(ra / 90) * 90
        ra = (ra + (lQuadrant - raQuadrant)) / 15
        let sinDec = 0.39782 * sin(l * .pi / 180)
        let cosDec = cos(asin(sinDec))
        let zenith = 90.833 * .pi / 180
        let cosH = (cos(zenith) - (sinDec * sin(lat))) / (cosDec * cos(lat))
        guard cosH >= -1, cosH <= 1 else { return nil } // polar day/night
        var h = rising ? 360 - acos(cosH) * 180 / .pi : acos(cosH) * 180 / .pi
        h /= 15
        let localT = h + ra - (0.06571 * t) - 6.622
        var ut = localT - lngHour
        ut = ut.truncatingRemainder(dividingBy: 24); if ut < 0 { ut += 24 }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        guard let dayStartUTC = utc.date(from: comps) else { return nil }
        let result = dayStartUTC.addingTimeInterval(ut * 3600)
        // Shift so the event lands on the local calendar day of `date`.
        let offset = Double(timeZone.secondsFromGMT(for: date))
        let localDayStart = calendar.startOfDay(for: date)
        var candidate = result
        if candidate < localDayStart { candidate = candidate.addingTimeInterval(86_400) }
        if candidate >= localDayStart.addingTimeInterval(86_400) { candidate = candidate.addingTimeInterval(-86_400) }
        _ = offset
        return candidate
    }
}
