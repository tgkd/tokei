import Foundation
import simd

struct SolarPosition {
    let declination: Double
    let subsolarLongitude: Double

    init(date: Date) {
        let julianDay = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let t = (julianDay - 2_451_545) / 36_525

        let meanLongitude = Self.degrees(280.46646 + t * (36_000.76983 + t * 0.0003032))
        let meanAnomaly = 357.52911 + t * (35_999.05029 - 0.0001537 * t)
        let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let anomalyRadians = meanAnomaly * .pi / 180
        let center = sin(anomalyRadians) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * anomalyRadians) * (0.019993 - 0.000101 * t)
            + sin(3 * anomalyRadians) * 0.000289
        let omega = (125.04 - 1934.136 * t) * .pi / 180
        let apparentLongitude = (meanLongitude + center - 0.00569 - 0.00478 * sin(omega)) * .pi / 180
        let meanObliquity = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
        let obliquity = (meanObliquity + 0.00256 * cos(omega)) * .pi / 180

        declination = asin(sin(obliquity) * sin(apparentLongitude))

        let y = pow(tan(obliquity / 2), 2)
        let longitudeRadians = meanLongitude * .pi / 180
        let equationOfTime = 4 * (180 / .pi) * (
            y * sin(2 * longitudeRadians)
                - 2 * eccentricity * sin(anomalyRadians)
                + 4 * eccentricity * y * sin(anomalyRadians) * cos(2 * longitudeRadians)
                - 0.5 * y * y * sin(4 * longitudeRadians)
                - 1.25 * eccentricity * eccentricity * sin(2 * anomalyRadians)
        )

        let secondsIntoDay = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86_400)
        let utcMinutes = (secondsIntoDay < 0 ? secondsIntoDay + 86_400 : secondsIntoDay) / 60
        let longitudeDegrees = Self.wrap((720 - utcMinutes - equationOfTime) / 4)
        subsolarLongitude = longitudeDegrees * .pi / 180
    }

    var direction: SIMD3<Double> {
        SIMD3(
            cos(declination) * sin(subsolarLongitude),
            sin(declination),
            cos(declination) * cos(subsolarLongitude)
        )
    }

    func altitude(at point: GeoPoint) -> Double {
        let latitude = point.latitude * .pi / 180
        let longitude = point.longitude * .pi / 180
        let sine = sin(latitude) * sin(declination)
            + cos(latitude) * cos(declination) * cos(longitude - subsolarLongitude)
        return asin(max(-1, min(1, sine)))
    }

    func isMorning(at point: GeoPoint) -> Bool {
        let hourAngle = Self.wrap(point.longitude - subsolarLongitude * 180 / .pi)
        return hourAngle < 0
    }

    private static func degrees(_ value: Double) -> Double {
        let wrapped = value.truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }

    private static func wrap(_ degrees: Double) -> Double {
        var value = degrees.truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value <= -180 { value += 360 }
        return value
    }
}
