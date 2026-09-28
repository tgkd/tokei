import Foundation
import simd

struct MountainRange {
    enum Summit {
        case massif
        case horn
        case volcano
        case plateau
        case spire
        case twin
    }

    let path: [SIMD2<Double>]
    let summitLocation: SIMD2<Double>
    let summit: Summit
    let summitHeight: Double
    let summitRadius: Double
    let width: Double
    let ridgeHeight: Double
    let peakCount: Int
    let peakHeight: ClosedRange<Double>
    let peakRadius: ClosedRange<Double>
    let seed: UInt64

    static let iconic = [
        MountainRange(
            path: [SIMD2(35.2, 74.6), SIMD2(34.0, 76.5), SIMD2(32.3, 78.2), SIMD2(30.6, 79.9), SIMD2(29.3, 82.3), SIMD2(28.3, 84.6), SIMD2(27.9, 86.9), SIMD2(27.7, 88.8), SIMD2(27.9, 91.5), SIMD2(28.6, 94.8)],
            summitLocation: SIMD2(27.99, 86.93), summit: .massif, summitHeight: 0.06, summitRadius: 3.2,
            width: 2.2, ridgeHeight: 0.018, peakCount: 16, peakHeight: 0.022...0.042, peakRadius: 1.1...2.0, seed: 11
        ),
        MountainRange(
            path: [SIMD2(44.2, 7.2), SIMD2(45.3, 6.9), SIMD2(45.9, 7.6), SIMD2(46.4, 8.9), SIMD2(46.6, 10.4), SIMD2(47.0, 11.8), SIMD2(47.2, 13.2), SIMD2(47.5, 14.8)],
            summitLocation: SIMD2(45.98, 7.66), summit: .horn, summitHeight: 0.042, summitRadius: 1.9,
            width: 1.3, ridgeHeight: 0.012, peakCount: 10, peakHeight: 0.018...0.03, peakRadius: 0.8...1.4, seed: 23
        ),
        MountainRange(
            path: [SIMD2(4.5, -75.5), SIMD2(0, -78), SIMD2(-5, -79), SIMD2(-9, -77.5), SIMD2(-12, -75.5), SIMD2(-16, -72), SIMD2(-20, -68.5), SIMD2(-24, -67.5), SIMD2(-28, -68.8), SIMD2(-32.65, -70.0), SIMD2(-36, -70.8), SIMD2(-40, -71.5), SIMD2(-45, -72.5), SIMD2(-49, -73.3)],
            summitLocation: SIMD2(-32.65, -70.0), summit: .spire, summitHeight: 0.05, summitRadius: 2.2,
            width: 1.6, ridgeHeight: 0.016, peakCount: 22, peakHeight: 0.02...0.038, peakRadius: 1.0...1.8, seed: 37
        ),
        MountainRange(
            path: [SIMD2(60.2, -153.6), SIMD2(61.5, -152.8), SIMD2(62.6, -151.6), SIMD2(63.07, -151.0), SIMD2(63.4, -149.0), SIMD2(63.5, -146.5), SIMD2(62.8, -143.5)],
            summitLocation: SIMD2(63.07, -151.0), summit: .spire, summitHeight: 0.05, summitRadius: 2.6,
            width: 1.4, ridgeHeight: 0.014, peakCount: 8, peakHeight: 0.02...0.035, peakRadius: 0.9...1.6, seed: 41
        ),
        MountainRange(
            path: [SIMD2(44.0, 39.3), SIMD2(43.5, 41.3), SIMD2(43.35, 42.44), SIMD2(42.9, 44.2), SIMD2(42.4, 45.8), SIMD2(41.8, 47.5), SIMD2(41.2, 48.9)],
            summitLocation: SIMD2(43.35, 42.44), summit: .twin, summitHeight: 0.04, summitRadius: 2.0,
            width: 1.1, ridgeHeight: 0.011, peakCount: 7, peakHeight: 0.016...0.028, peakRadius: 0.8...1.3, seed: 53
        ),
        MountainRange(
            path: [SIMD2(-0.15, 37.3), SIMD2(-1.6, 37.0), SIMD2(-3.07, 37.35), SIMD2(-3.25, 36.75)],
            summitLocation: SIMD2(-3.07, 37.35), summit: .plateau, summitHeight: 0.036, summitRadius: 2.6,
            width: 1.0, ridgeHeight: 0.006, peakCount: 3, peakHeight: 0.016...0.026, peakRadius: 1.0...1.6, seed: 67
        ),
        MountainRange(
            path: [SIMD2(35.36, 138.73), SIMD2(35.8, 137.8), SIMD2(36.3, 137.6), SIMD2(36.8, 137.7)],
            summitLocation: SIMD2(35.5, 138.6), summit: .volcano, summitHeight: 0.034, summitRadius: 1.4,
            width: 0.8, ridgeHeight: 0.008, peakCount: 4, peakHeight: 0.012...0.02, peakRadius: 0.6...0.9, seed: 79
        ),
    ]

    func carve() -> CarvedRange {
        var random = SeededRandom(state: seed)
        let points = path.map { Self.unit($0) }
        let lengths = zip(points, points.dropFirst()).map { acos(min(max(dot($0, $1), -1), 1)) }
        let total = lengths.reduce(0, +)
        let halfWidth = width * .pi / 180
        let summitPoint = Self.unit(summitLocation)
        let summitAngle = summitRadius * .pi / 180

        var peaks = summitPeaks(at: summitPoint, angle: summitAngle, random: &random)
        for index in 0..<peakCount {
            let along = (Double(index) + 0.5 + .random(in: -0.35...0.35, using: &random)) / Double(peakCount) * total
            let (point, side) = Self.locate(along: along, points: points, lengths: lengths)
            let offset = Double.random(in: -0.45...0.45, using: &random) * halfWidth
            let center = normalize(point * cos(offset) + side * sin(offset))
            guard acos(min(dot(center, summitPoint), 1)) > summitAngle * 0.75 else { continue }
            peaks.append(Peak.random(
                at: center,
                angle: Double.random(in: peakRadius, using: &random) * .pi / 180,
                height: .random(in: peakHeight, using: &random),
                sides: .random(in: 4...7, using: &random),
                random: &random
            ))
        }

        let center = normalize(points.reduce(.zero, +))
        let spread = points.map { acos(min(dot($0, center), 1)) }.max() ?? 0
        let reach = spread + max(halfWidth, peaks.map(\.angle).max() ?? 0) * 1.4
        return CarvedRange(
            center: center,
            reach: cos(min(reach, .pi)),
            points: points,
            lengths: lengths,
            halfWidth: halfWidth,
            ridgeHeight: ridgeHeight,
            lumps: (0..<2).map { _ in SIMD2(Double.random(in: 18...40, using: &random), .random(in: 0..<(2 * .pi), using: &random)) },
            peaks: peaks,
            tallest: max(summitHeight, peakHeight.upperBound)
        )
    }

    private func summitPeaks(at point: SIMD3<Double>, angle: Double, random: inout SeededRandom) -> [Peak] {
        switch summit {
        case .massif:
            let (east, north) = Self.frame(point)
            let shoulders = [(SIMD2(0.42, -0.2), 0.55, 0.72), (SIMD2(-0.38, 0.28), 0.5, 0.66)]
            return [Peak.random(at: point, angle: angle, height: summitHeight, sides: 6, random: &random)]
                + shoulders.map { offset, scale, share in
                    let center = normalize(point + (east * offset.x + north * offset.y) * angle)
                    return Peak.random(at: center, angle: angle * scale, height: summitHeight * share, sides: 5, random: &random)
                }
        case .horn:
            return [Peak.random(at: point, angle: angle, height: summitHeight, sides: 4, sharpness: 1.0, random: &random)]
        case .volcano:
            return [Peak.random(at: point, angle: angle, height: summitHeight, sides: 12, sharpness: 1.3, flatten: 1.12, random: &random)]
        case .plateau:
            return [Peak.random(at: point, angle: angle, height: summitHeight, sides: 9, sharpness: 1.0, flatten: 1.35, random: &random)]
        case .spire:
            return [Peak.random(at: point, angle: angle, height: summitHeight, sides: 6, sharpness: 1.15, random: &random)]
        case .twin:
            let (east, north) = Self.frame(point)
            return [SIMD2(-0.26, 0.0), SIMD2(0.26, 0.05)].enumerated().map { index, offset in
                let center = normalize(point + (east * offset.x + north * offset.y) * angle)
                return Peak.random(at: center, angle: angle * 0.7, height: summitHeight * (index == 0 ? 1 : 0.94), sides: 7, random: &random)
            }
        }
    }

    static func unit(_ location: SIMD2<Double>) -> SIMD3<Double> {
        let latitude = location.x * .pi / 180
        let longitude = location.y * .pi / 180
        return SIMD3(cos(latitude) * sin(longitude), sin(latitude), cos(latitude) * cos(longitude))
    }

    static func frame(_ point: SIMD3<Double>) -> (east: SIMD3<Double>, north: SIMD3<Double>) {
        let helper: SIMD3<Double> = abs(point.y) < 0.9 ? SIMD3(0, 1, 0) : SIMD3(1, 0, 0)
        let east = normalize(cross(helper, point))
        return (east, cross(point, east))
    }

    private static func locate(along: Double, points: [SIMD3<Double>], lengths: [Double]) -> (point: SIMD3<Double>, side: SIMD3<Double>) {
        var remaining = min(max(along, 0), lengths.reduce(0, +))
        for (index, length) in lengths.enumerated() {
            if remaining <= length || index == lengths.count - 1 {
                let start = points[index]
                let end = points[index + 1]
                let side = normalize(cross(start, end))
                let fraction = length > 0 ? min(remaining / length, 1) : 0
                let point = normalize(start * sin((1 - fraction) * length) + end * sin(fraction * length))
                return (length > 0 ? point : start, side)
            }
            remaining -= length
        }
        return (points[0], SIMD3(0, 1, 0))
    }
}

struct Peak {
    let center: SIMD3<Double>
    let east: SIMD3<Double>
    let north: SIMD3<Double>
    let angle: Double
    let height: Double
    let rotation: Double
    let apex: SIMD2<Double>
    let insets: [Double]
    let sharpness: Double
    let flatten: Double

    static func random(
        at center: SIMD3<Double>,
        angle: Double,
        height: Double,
        sides: Int,
        sharpness: Double? = nil,
        flatten: Double = 1,
        random: inout SeededRandom
    ) -> Peak {
        let (east, north) = MountainRange.frame(center)
        return Peak(
            center: center,
            east: east,
            north: north,
            angle: angle,
            height: height,
            rotation: .random(in: 0..<(2 * .pi), using: &random),
            apex: SIMD2(.random(in: -0.15...0.15, using: &random), .random(in: -0.15...0.15, using: &random)),
            insets: (0..<sides).map { _ in .random(in: 0.8...1.2, using: &random) },
            sharpness: sharpness ?? .random(in: 1.0...1.35, using: &random),
            flatten: flatten
        )
    }

    func height(at direction: SIMD3<Double>) -> Double {
        guard dot(direction, center) > cos(angle * 1.3) else { return 0 }
        let point = SIMD2(dot(direction, east), dot(direction, north)) / angle
        let sides = insets.count
        var level = 1.0
        for (side, inset) in insets.enumerated() {
            let facing = rotation + (Double(side) + 0.5) * 2 * .pi / Double(sides)
            let normal = SIMD2(cos(facing), sin(facing))
            let edge = cos(.pi / Double(sides)) * inset
            level = min(level, 1 - dot(point - apex, normal) / (edge - dot(apex, normal)))
        }
        return height * pow(min(max(level, 0) * flatten, 1), sharpness)
    }
}

struct CarvedRange {
    let center: SIMD3<Double>
    let reach: Double
    let points: [SIMD3<Double>]
    let lengths: [Double]
    let halfWidth: Double
    let ridgeHeight: Double
    let lumps: [SIMD2<Double>]
    let peaks: [Peak]
    let tallest: Double

    func height(at direction: SIMD3<Double>) -> Double {
        guard dot(direction, center) > reach else { return 0 }
        var rise = ridge(at: direction)
        for peak in peaks {
            rise = max(rise, peak.height(at: direction))
        }
        return rise
    }

    private func ridge(at direction: SIMD3<Double>) -> Double {
        var nearest = Double.greatestFiniteMagnitude
        var along = 0.0
        var travelled = 0.0
        for (index, length) in lengths.enumerated() {
            let start = points[index]
            let end = points[index + 1]
            let normal = normalize(cross(start, end))
            let offset = asin(min(max(dot(direction, normal), -1), 1))
            let projected = normalize(direction - normal * dot(direction, normal))
            let fromStart = atan2(dot(cross(start, projected), normal), dot(start, projected))
            let distance: Double
            let position: Double
            if fromStart >= 0 && fromStart <= length {
                distance = abs(offset)
                position = travelled + fromStart
            } else {
                let toStart = acos(min(max(dot(direction, start), -1), 1))
                let toEnd = acos(min(max(dot(direction, end), -1), 1))
                distance = min(toStart, toEnd)
                position = toStart < toEnd ? travelled : travelled + length
            }
            if distance < nearest {
                nearest = distance
                along = position
            }
            travelled += length
        }
        guard nearest < halfWidth else { return 0 }
        let lump = lumps.reduce(0.55) { $0 + 0.225 * (1 + sin($1.x * along + $1.y)) }
        return ridgeHeight * lump * pow(1 - nearest / halfWidth, 1.6)
    }
}

struct SeededRandom: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}
