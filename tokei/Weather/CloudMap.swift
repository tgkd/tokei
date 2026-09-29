import Foundation
import simd

enum PrecipitationKind: UInt8, Sendable {
    case unknown = 0
    case snow = 1
    case mixed = 2
    case rain = 3
}

struct CloudMap: Sendable {
    static let width = 1440
    static let height = 720
    static let threshold: Float = 0.38
    static let puffAmplitude: Float = 0.2
    static let edgeGain: Float = 3
    static let precipitationThreshold: Float = (0.2 / 8 as Float).squareRoot()
    private static let thinWater: Float = 0.03
    private static let thickWater: Float = 1.0
    private static let heavyRain: Float = 8

    let texels: [UInt8]

    init(cloudWater: WeatherGrid, precipitation: WeatherGrid, kinds: [PrecipitationKind]) {
        let width = Self.width
        let height = Self.height
        let sourceWidth = cloudWater.width
        let sourceHeight = cloudWater.height
        let columnTaps = (0..<width).map { column -> Tap in
            var longitude = ((Double(column) + 0.5) / Double(width) - 0.5) * 360
            if longitude < 0 {
                longitude += 360
            }
            return Tap(position: longitude * Double(sourceWidth) / 360, count: sourceWidth, wraps: true)
        }
        let rowTaps = (0..<height).map { row -> Tap in
            Tap(position: (Double(row) + 0.5) / Double(height) * Double(sourceHeight - 1), count: sourceHeight, wraps: false)
        }
        let clouds = Self.spread(cloudWater.values.map(Self.cloudiness), sourceWidth: sourceWidth, sourceHeight: sourceHeight, taps: columnTaps)
        let rains = Self.spread(precipitation.values.map(Self.wetness), sourceWidth: sourceWidth, sourceHeight: sourceHeight, taps: columnTaps)
        let band = Self.puffAmplitude + 0.5 / Self.edgeGain
        var texels = [UInt8](repeating: 0, count: width * height * 4)
        texels.withUnsafeMutableBufferPointer { output in
            clouds.withUnsafeBufferPointer { clouds in
                rains.withUnsafeBufferPointer { rains in
                    columnTaps.withUnsafeBufferPointer { columnTaps in
                        kinds.withUnsafeBufferPointer { kinds in
                            let target = output.baseAddress!
                            DispatchQueue.concurrentPerform(iterations: height) { row in
                                let tap = rowTaps[row]
                                let latitude = (0.5 - (Double(row) + 0.5) / Double(height)) * .pi
                                let ring = cos(latitude)
                                let lift = sin(latitude)
                                let r0 = tap.i0 * width
                                let r1 = tap.i1 * width
                                let r2 = tap.i2 * width
                                let r3 = tap.i3 * width
                                for column in 0..<width {
                                    var field = tap.w0 * clouds[r0 + column] + tap.w1 * clouds[r1 + column] + tap.w2 * clouds[r2 + column] + tap.w3 * clouds[r3 + column]
                                    field = min(max(field, 0), 1)
                                    var wet = tap.w0 * rains[r0 + column] + tap.w1 * rains[r1 + column] + tap.w2 * rains[r2 + column] + tap.w3 * rains[r3 + column]
                                    wet = min(max(wet, 0), 1)
                                    var mask = field - Self.threshold
                                    if abs(mask) < band {
                                        let longitude = ((Double(column) + 0.5) / Double(width) - 0.5) * 2 * .pi
                                        mask += Self.puffAmplitude * (Self.puffs(ring * sin(longitude), lift, ring * cos(longitude)) - 0.45)
                                    }
                                    let kind = kinds.isEmpty ? PrecipitationKind.unknown : kinds[tap.nearest * sourceWidth + columnTaps[column].nearest]
                                    let index = (row * width + column) * 4
                                    target[index] = Self.byte(0.5 + mask * Self.edgeGain)
                                    target[index + 1] = Self.byte(field)
                                    target[index + 2] = Self.byte(wet)
                                    target[index + 3] = kind.rawValue * 64
                                }
                            }
                        }
                    }
                }
            }
        }
        self.texels = texels
    }

    func mask(at direction: SIMD3<Double>) -> Float {
        bilinear(channel: 0, at: direction)
    }

    func wetness(at direction: SIMD3<Double>) -> Float {
        bilinear(channel: 2, at: direction)
    }

    func kind(at direction: SIMD3<Double>) -> PrecipitationKind {
        let texel = Self.texelPosition(of: direction)
        let column = ((Int(floor(texel.x + 0.5)) % Self.width) + Self.width) % Self.width
        let row = min(max(Int(floor(texel.y + 0.5)), 0), Self.height - 1)
        return PrecipitationKind(rawValue: texels[(row * Self.width + column) * 4 + 3] / 64) ?? .unknown
    }

    func isRaining(at direction: SIMD3<Double>) -> Bool {
        wetness(at: direction) >= Self.precipitationThreshold
    }

    private func bilinear(channel: Int, at direction: SIMD3<Double>) -> Float {
        let texel = Self.texelPosition(of: direction)
        let column = Int(floor(texel.x))
        let row = Int(floor(texel.y))
        let tx = Float(texel.x - floor(texel.x))
        let ty = Float(texel.y - floor(texel.y))
        func value(_ column: Int, _ row: Int) -> Float {
            let wrapped = ((column % Self.width) + Self.width) % Self.width
            let clamped = min(max(row, 0), Self.height - 1)
            return Float(texels[(clamped * Self.width + wrapped) * 4 + channel]) / 255
        }
        let top = value(column, row) * (1 - tx) + value(column + 1, row) * tx
        let bottom = value(column, row + 1) * (1 - tx) + value(column + 1, row + 1) * tx
        return top * (1 - ty) + bottom * ty
    }

    static func texelPosition(of direction: SIMD3<Double>) -> SIMD2<Double> {
        let longitude = atan2(direction.x, direction.z)
        let latitude = asin(min(max(direction.y, -1), 1))
        let u = longitude / (2 * .pi) + 0.5
        let v = 0.5 - latitude / .pi
        return SIMD2(u * Double(width) - 0.5, v * Double(height) - 0.5)
    }

    static func kinds(rain: WeatherGrid?, snow: WeatherGrid?, freezing: WeatherGrid?, pellets: WeatherGrid?, count: Int) -> [PrecipitationKind] {
        guard rain != nil || snow != nil || freezing != nil || pellets != nil else { return [] }
        return (0..<count).map { index in
            let isRain = (rain?.values[index] ?? 0) >= 0.5
            let isSnow = (snow?.values[index] ?? 0) >= 0.5
            let isIce = (freezing?.values[index] ?? 0) >= 0.5 || (pellets?.values[index] ?? 0) >= 0.5
            if isIce || (isRain && isSnow) {
                return .mixed
            }
            if isSnow {
                return .snow
            }
            if isRain {
                return .rain
            }
            return .unknown
        }
    }

    private static func cloudiness(_ water: Float) -> Float {
        guard water > thinWater else { return 0 }
        return min(log(water / thinWater) / log(thickWater / thinWater), 1)
    }

    private static func wetness(_ rate: Float) -> Float {
        min(max(rate * 3600 / heavyRain, 0), 1).squareRoot()
    }

    private static func byte(_ value: Float) -> UInt8 {
        UInt8(min(max(value, 0), 1) * 255 + 0.5)
    }

    private static func spread(_ values: [Float], sourceWidth: Int, sourceHeight: Int, taps: [Tap]) -> [Float] {
        let width = taps.count
        var rows = [Float](repeating: 0, count: sourceHeight * width)
        rows.withUnsafeMutableBufferPointer { rows in
            values.withUnsafeBufferPointer { values in
                taps.withUnsafeBufferPointer { taps in
                    for row in 0..<sourceHeight {
                        let source = row * sourceWidth
                        let target = row * width
                        for column in 0..<width {
                            let tap = taps[column]
                            rows[target + column] = tap.w0 * values[source + tap.i0] + tap.w1 * values[source + tap.i1] + tap.w2 * values[source + tap.i2] + tap.w3 * values[source + tap.i3]
                        }
                    }
                }
            }
        }
        return rows
    }

    private static func puffs(_ x: Double, _ y: Double, _ z: Double) -> Float {
        Float(0.65 * puff(x * 40, y * 40, z * 40, seed: 0x9E37_79B9) + 0.35 * puff(x * 95, y * 95, z * 95, seed: 0x85EB_CA6B))
    }

    private static func puff(_ x: Double, _ y: Double, _ z: Double, seed: UInt32) -> Double {
        let cellX = floor(x)
        let cellY = floor(y)
        let cellZ = floor(z)
        var best = 0.0
        var dz = -1.0
        while dz <= 1 {
            let cornerZ = cellZ + dz
            let gapZ = max(cornerZ + 0.15 - z, z - cornerZ - 0.85, 0)
            var dy = -1.0
            while dy <= 1 {
                let cornerY = cellY + dy
                let gapY = max(cornerY + 0.15 - y, y - cornerY - 0.85, 0)
                var dx = -1.0
                while dx <= 1 {
                    let cornerX = cellX + dx
                    let gapX = max(cornerX + 0.15 - x, x - cornerX - 0.85, 0)
                    if gapX * gapX + gapY * gapY + gapZ * gapZ < 0.9025 {
                        var state = seed
                        state = mix(state, UInt32(bitPattern: Int32(truncatingIfNeeded: Int(cornerX))))
                        state = mix(state, UInt32(bitPattern: Int32(truncatingIfNeeded: Int(cornerY))))
                        state = mix(state, UInt32(bitPattern: Int32(truncatingIfNeeded: Int(cornerZ))))
                        let offsetX = x - (cornerX + 0.15 + 0.7 * unit(&state))
                        let offsetY = y - (cornerY + 0.15 + 0.7 * unit(&state))
                        let offsetZ = z - (cornerZ + 0.15 + 0.7 * unit(&state))
                        let radius = 0.55 + 0.4 * unit(&state)
                        let reach = (offsetX * offsetX + offsetY * offsetY + offsetZ * offsetZ) / (radius * radius)
                        if reach < 1 {
                            let rest = 1 - reach
                            best = max(best, rest * rest)
                        }
                    }
                    dx += 1
                }
                dy += 1
            }
            dz += 1
        }
        return best
    }

    private static func mix(_ state: UInt32, _ value: UInt32) -> UInt32 {
        var hash = state ^ (value &* 0x27D4_EB2D)
        hash = (hash ^ (hash >> 15)) &* 0x2C1B_3C6D
        hash = (hash ^ (hash >> 12)) &* 0x297A_2D39
        return hash ^ (hash >> 15)
    }

    private static func unit(_ state: inout UInt32) -> Double {
        state = mix(state, 0x6A09_E667)
        return Double(state >> 8) / Double(1 << 24)
    }
}

private struct Tap {
    let i0: Int
    let i1: Int
    let i2: Int
    let i3: Int
    let w0: Float
    let w1: Float
    let w2: Float
    let w3: Float
    let nearest: Int

    init(position: Double, count: Int, wraps: Bool) {
        let base = Int(floor(position))
        let t = Float(position - floor(position))
        let s = 1 - t
        func index(_ offset: Int) -> Int {
            let raw = base + offset
            return wraps ? ((raw % count) + count) % count : min(max(raw, 0), count - 1)
        }
        i0 = index(-1)
        i1 = index(0)
        i2 = index(1)
        i3 = index(2)
        w0 = s * s * s / 6
        w1 = (3 * t * t * t - 6 * t * t + 4) / 6
        w2 = (-3 * t * t * t + 3 * t * t + 3 * t + 1) / 6
        w3 = t * t * t / 6
        nearest = index(Int(position.rounded()) - base)
    }
}
