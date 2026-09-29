import Foundation
import simd

struct ChipWeather: Hashable {
    let symbol: String
    let text: String
    let accessibilityLabel: String

    static func make(frame: GlobeFrame, direction: SIMD3<Double>, date: Date, homeZone: TimeZone, status: WeatherFeed.Status) -> ChipWeather? {
        guard frame.style.hasClouds else { return nil }
        guard let weather = frame.weather else {
            switch status {
            case .unavailable:
                return ChipWeather(symbol: "cloud", text: "No weather", accessibilityLabel: "Weather unavailable")
            case .idle:
                return nil
            default:
                return ChipWeather(symbol: "ellipsis", text: "Weather", accessibilityLabel: "Loading weather")
            }
        }
        let conditions = weather.conditions(at: direction, sun: frame.sun)
        let held = weather.validDate != WeatherSchedule.validDate(near: date)
        let when = ZoneClock.time(weather.validDate, in: homeZone)
        var parts: [String] = []
        var spoken: [String] = []
        if let kelvin = conditions.kelvin {
            let measurement = Measurement(value: kelvin, unit: UnitTemperature.kelvin)
            let rounded = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0))
            parts.append("~" + measurement.formatted(.measurement(width: .narrow, usage: .weather, numberFormatStyle: rounded)))
            spoken.append("about " + measurement.formatted(.measurement(width: .wide, usage: .weather, numberFormatStyle: rounded)))
        }
        if let summary = conditions.summary {
            spoken.append(summary)
        }
        if held {
            parts.append(when)
        }
        spoken.append(held ? "model estimate for \(when)" : "model estimate")
        guard let symbol = conditions.symbol ?? (parts.isEmpty ? nil : "thermometer.medium") else { return nil }
        return ChipWeather(symbol: symbol, text: parts.joined(separator: " · "), accessibilityLabel: spoken.joined(separator: ", "))
    }
}
