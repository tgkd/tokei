import Foundation

enum Daylight: Equatable {
    case day
    case dawn
    case dusk
    case night

    var symbolName: String {
        switch self {
        case .day: "sun.max.fill"
        case .dawn: "sunrise.fill"
        case .dusk: "sunset.fill"
        case .night: "moon.stars.fill"
        }
    }
}

enum ZoneClock {
    static func time(_ date: Date, in zone: TimeZone) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: zone))
    }

    static func weekdayAndDate(_ date: Date, in zone: TimeZone) -> String {
        date.formatted(Date.FormatStyle(timeZone: zone).weekday(.abbreviated).day().month(.abbreviated))
    }

    static func offsetMinutes(of zone: TimeZone, from reference: TimeZone, at date: Date) -> Int {
        (zone.secondsFromGMT(for: date) - reference.secondsFromGMT(for: date)) / 60
    }

    static func offsetLabel(minutes: Int) -> String {
        guard minutes != 0 else { return "Same time" }
        let sign = minutes > 0 ? "+" : "−"
        let hours = abs(minutes) / 60
        let rest = abs(minutes) % 60
        if rest == 0 {
            return "\(sign)\(hours)h"
        }
        return "\(sign)\(hours):\(String(format: "%02d", rest))"
    }

    static func gmtLabel(of zone: TimeZone, at date: Date) -> String {
        let minutes = zone.secondsFromGMT(for: date) / 60
        guard minutes != 0 else { return "GMT" }
        let sign = minutes > 0 ? "+" : "−"
        let hours = abs(minutes) / 60
        let rest = abs(minutes) % 60
        if rest == 0 {
            return "GMT\(sign)\(hours)"
        }
        return "GMT\(sign)\(hours):\(String(format: "%02d", rest))"
    }

    static func dayDelta(of zone: TimeZone, from reference: TimeZone, at date: Date) -> Int {
        civilDayNumber(date, in: zone) - civilDayNumber(date, in: reference)
    }

    static func dayDeltaLabel(_ delta: Int) -> String? {
        switch delta {
        case 0: nil
        case 1: "Tomorrow"
        case -1: "Yesterday"
        default: delta > 0 ? "+\(delta) days" : "−\(abs(delta)) days"
        }
    }

    static func shiftLabel(minutes: Int) -> String {
        guard minutes != 0 else { return "Now" }
        let sign = minutes > 0 ? "+" : "−"
        let total = abs(minutes)
        let days = total / 1440
        let hours = (total % 1440) / 60
        let rest = total % 60
        var parts: [String] = []
        if days > 0 {
            parts.append("\(days)d")
        }
        if hours > 0 {
            parts.append("\(hours)h")
        }
        if rest > 0 && days == 0 {
            parts.append("\(rest)m")
        }
        if parts.isEmpty {
            parts.append("0m")
        }
        return sign + parts.joined(separator: " ")
    }

    static func daylight(at point: GeoPoint, sun: SolarPosition) -> Daylight {
        let altitude = sun.altitude(at: point) * 180 / .pi
        if altitude > 6 {
            return .day
        }
        if altitude < -6 {
            return .night
        }
        return sun.isMorning(at: point) ? .dawn : .dusk
    }

    private static func civilDayNumber(_ date: Date, in zone: TimeZone) -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 2000
        let month = components.month ?? 1
        let day = components.day ?? 1
        let a = (14 - month) / 12
        let y = year + 4800 - a
        let m = month + 12 * a - 3
        return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32_045
    }
}
