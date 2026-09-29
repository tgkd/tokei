import Foundation
import simd

final class WeatherFrame: Equatable, Sendable {
    enum Failure: Error {
        case incomplete
    }

    let key: WeatherKey
    let map: CloudMap
    let cloudCover: WeatherGrid?
    let temperature: WeatherGrid?

    init(bundle: WeatherBundle) throws {
        let key = bundle.key
        func grid(_ field: WeatherField) -> WeatherGrid? {
            guard let data = bundle.records[field], let decoded = try? GribField(data: data, identity: field.identity, forecastHours: key.lead) else { return nil }
            return WeatherGrid(decoded)
        }
        guard let water = grid(.cloudWater), let precipitation = grid(.precipitation), water.matches(precipitation) else {
            throw Failure.incomplete
        }
        let flags = [grid(.rain), grid(.snow), grid(.freezingRain), grid(.icePellets)].map { $0.flatMap { $0.matches(water) ? $0 : nil } }
        let kinds = CloudMap.kinds(rain: flags[0], snow: flags[1], freezing: flags[2], pellets: flags[3], count: water.values.count)
        self.key = key
        map = CloudMap(cloudWater: water, precipitation: precipitation, kinds: kinds)
        cloudCover = grid(.cloudCover).flatMap { $0.matches(water) ? $0 : nil }
        temperature = grid(.temperature).flatMap { $0.matches(water) ? $0 : nil }
    }

    var validDate: Date {
        key.validDate
    }

    static func == (lhs: WeatherFrame, rhs: WeatherFrame) -> Bool {
        lhs === rhs
    }

    func conditions(at direction: SIMD3<Double>, sun: SIMD3<Double>) -> CityConditions {
        let precipitation = map.isRaining(at: direction) ? map.kind(at: direction) : nil
        let sky = cloudCover.map { CityConditions.Sky(cover: $0.bilinear(at: direction)) }
        return CityConditions(
            sky: sky,
            precipitation: precipitation,
            isDay: dot(direction, sun) > 0,
            kelvin: temperature.map { Double($0.bilinear(at: direction)) }
        )
    }
}

struct CityConditions: Equatable {
    enum Sky: Equatable {
        case clear
        case partly
        case overcast

        init(cover: Float) {
            if cover < 25 {
                self = .clear
            } else if cover < 75 {
                self = .partly
            } else {
                self = .overcast
            }
        }
    }

    let sky: Sky?
    let precipitation: PrecipitationKind?
    let isDay: Bool
    let kelvin: Double?

    var symbol: String? {
        if let precipitation {
            switch precipitation {
            case .snow: return "cloud.snow.fill"
            case .mixed: return "cloud.sleet.fill"
            case .rain: return "cloud.rain.fill"
            case .unknown: return "cloud.drizzle.fill"
            }
        }
        switch sky {
        case .clear: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case .partly: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case .overcast: return "cloud.fill"
        case nil: return nil
        }
    }

    var summary: String? {
        if let precipitation {
            switch precipitation {
            case .snow: return "snow"
            case .mixed: return "mixed precipitation"
            case .rain: return "rain"
            case .unknown: return "precipitation"
            }
        }
        switch sky {
        case .clear: return "clear"
        case .partly: return "partly cloudy"
        case .overcast: return "cloudy"
        case nil: return nil
        }
    }
}
