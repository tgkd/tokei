import Foundation

enum WeatherField: String, CaseIterable, Codable, Sendable {
    case cloudWater
    case precipitation
    case cloudCover
    case temperature
    case rain
    case snow
    case freezingRain
    case icePellets

    var parameter: String {
        switch self {
        case .cloudWater: "CWAT"
        case .precipitation: "PRATE"
        case .cloudCover: "TCDC"
        case .temperature: "TMP"
        case .rain: "CRAIN"
        case .snow: "CSNOW"
        case .freezingRain: "CFRZR"
        case .icePellets: "CICEP"
        }
    }

    var level: String {
        switch self {
        case .cloudWater: "entire atmosphere (considered as a single layer)"
        case .cloudCover: "entire atmosphere"
        case .temperature: "2 m above ground"
        case .precipitation, .rain, .snow, .freezingRain, .icePellets: "surface"
        }
    }

    var identity: GribField.Identity {
        switch self {
        case .cloudWater: GribField.Identity(category: 6, number: 6)
        case .precipitation: GribField.Identity(category: 1, number: 7)
        case .cloudCover: GribField.Identity(category: 6, number: 1)
        case .temperature: GribField.Identity(category: 0, number: 0)
        case .rain: GribField.Identity(category: 1, number: 192)
        case .snow: GribField.Identity(category: 1, number: 195)
        case .freezingRain: GribField.Identity(category: 1, number: 193)
        case .icePellets: GribField.Identity(category: 1, number: 194)
        }
    }

    var isRequired: Bool {
        self == .cloudWater || self == .precipitation
    }

    func matches(_ entry: WeatherIndex.Entry, key: WeatherKey) -> Bool {
        entry.parameter == parameter && entry.level == level && entry.time == key.timeLabel
    }
}
