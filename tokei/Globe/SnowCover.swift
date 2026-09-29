import Foundation
import Metal
import simd

struct FootprintShape {
    struct Harmonic {
        let order: Double
        let amplitude: Double
        let phase: Double
    }

    struct Lobe {
        let offset: SIMD2<Double>
        let scale: Double
    }

    let radius: Double
    let rotation: Double
    let stretch: Double
    let harmonics: [Harmonic]
    let lobes: [Lobe]

    static func random(radius: Double) -> FootprintShape {
        let broad = (2...5).map { order in
            Harmonic(order: Double(order), amplitude: .random(in: 0.03...0.14), phase: .random(in: 0..<(2 * .pi)))
        }
        let ragged = (7...11).map { order in
            Harmonic(order: Double(order), amplitude: .random(in: 0.01...0.035), phase: .random(in: 0..<(2 * .pi)))
        }
        let lobes = (0..<Int.random(in: 0...2)).map { _ in
            let angle = Double.random(in: 0..<(2 * .pi))
            let distance = Double.random(in: 0.45...0.8)
            return Lobe(offset: SIMD2(cos(angle), sin(angle)) * distance, scale: .random(in: 0.4...0.65))
        }
        return FootprintShape(
            radius: radius,
            rotation: .random(in: 0..<(2 * .pi)),
            stretch: .random(in: 1...1.45),
            harmonics: broad + ragged,
            lobes: lobes
        )
    }

    var reach: Double {
        let edge = 1 + harmonics.reduce(0) { $0 + $1.amplitude }
        let lobeReach = lobes.map { length($0.offset) + $0.scale * edge }.max() ?? 0
        return radius * max(edge * stretch.squareRoot(), lobeReach * stretch.squareRoot())
    }

    func normalizedDistance(_ local: SIMD2<Double>) -> Double {
        let cosine = cos(rotation)
        let sine = sin(rotation)
        let aligned = SIMD2(cosine * local.x + sine * local.y, -sine * local.x + cosine * local.y) / radius
        let squeezed = SIMD2(aligned.x / stretch.squareRoot(), aligned.y * stretch.squareRoot())
        var nearest = profile(squeezed)
        for lobe in lobes {
            nearest = min(nearest, profile((squeezed - lobe.offset) / lobe.scale))
        }
        return nearest
    }

    private func profile(_ point: SIMD2<Double>) -> Double {
        let angle = atan2(point.y, point.x)
        let edge = harmonics.reduce(1) { $0 + $1.amplitude * cos($1.order * angle + $1.phase) }
        return length(point) / edge
    }
}

@MainActor
final class SnowCover {
    static let width = 2048
    static let height = 1024
    private static let settled = Float16(-1000)
    private static let rebaseAge = 256.0

    let texture: MTLTexture
    private(set) var epoch = Date()
    private var stamps: [Float16]
    private let columnSines: [Double]
    private let columnCosines: [Double]
    private let rowRings: [Double]
    private let rowHeights: [Double]
    private var dirtyRows: ClosedRange<Int>?
    private var dirtyColumns: ClosedRange<Int>?
    private var disturbedRows: ClosedRange<Int>?

    init?(device: MTLDevice) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r16Float, width: Self.width, height: Self.height, mipmapped: false)
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        self.texture = texture
        stamps = [Float16](repeating: Self.settled, count: Self.width * Self.height)
        let longitudes = (0..<Self.width).map { ((Double($0) + 0.5) / Double(Self.width) - 0.5) * 2 * .pi }
        columnSines = longitudes.map(sin)
        columnCosines = longitudes.map(cos)
        let latitudes = (0..<Self.height).map { (0.5 - (Double($0) + 0.5) / Double(Self.height)) * .pi }
        rowRings = latitudes.map(cos)
        rowHeights = latitudes.map(sin)
        upload(rows: 0...(Self.height - 1), columns: 0...(Self.width - 1))
    }

    func stamp(at direction: SIMD3<Double>, shape: FootprintShape, recovery: Double, hold: Double = 0, now: Date) {
        let time = clock(at: now, recovery: recovery)
        let east = Self.tangent(at: direction)
        let north = cross(direction, east)
        paint(around: direction, reach: shape.reach, time: time, recovery: recovery, hold: hold) { point in
            let distance = shape.normalizedDistance(SIMD2(dot(point, east), dot(point, north)))
            return 1 - Self.smoothstep(0.55, 1, distance)
        }
        flush()
    }

    func carve(from start: SIMD3<Double>, to end: SIMD3<Double>, trail: SnowTrail, recovery: Double, hold: Double, now: Date) {
        let time = clock(at: now, recovery: recovery)
        let arc = acos(min(max(dot(start, end), -1), 1))
        let pieces = max(Int((arc / (trail.radius * 0.5)).rounded(.up)), 1)
        var from = start
        for piece in 1...pieces {
            let fraction = Double(piece) / Double(pieces)
            let to = piece == pieces ? end : normalize(start + (end - start) * fraction)
            let distances = (trail.distance + arc * Double(piece - 1) / Double(pieces), trail.distance + arc * fraction)
            carve(from: from, to: to, distances: distances, trail: trail, time: time, recovery: recovery, hold: hold)
            from = to
        }
        flush()
    }

    func level(at direction: SIMD3<Double>, clock: Double, recovery: Double) -> Float {
        guard clock > 0 else { return 1 }
        let clock = Float(clock)
        let recovery = Float(recovery)
        let longitude = atan2(direction.x, direction.z)
        let latitude = asin(min(max(direction.y, -1), 1))
        let texelX = (longitude / (2 * .pi) + 0.5) * Double(Self.width) - 0.5
        let texelY = (0.5 - latitude / .pi) * Double(Self.height) - 0.5
        let column = Int(floor(texelX))
        let row = Int(floor(texelY))
        let tx = Float(texelX - floor(texelX))
        let ty = Float(texelY - floor(texelY))
        func refill(_ column: Int, _ row: Int) -> Float {
            let wrapped = ((column % Self.width) + Self.width) % Self.width
            let clamped = min(max(row, 0), Self.height - 1)
            return min(max((clock - Float(stamps[clamped * Self.width + wrapped])) / recovery, 0), 1)
        }
        let top = refill(column, row) * (1 - tx) + refill(column + 1, row) * tx
        let bottom = refill(column, row + 1) * (1 - tx) + refill(column + 1, row + 1) * tx
        return top * (1 - ty) + bottom * ty
    }

    func reset() {
        epoch = Date()
        guard let rows = disturbedRows else { return }
        disturbedRows = nil
        settle(rows: rows)
        upload(rows: rows, columns: 0...(Self.width - 1))
    }

    private func carve(
        from start: SIMD3<Double>,
        to end: SIMD3<Double>,
        distances: (Double, Double),
        trail: SnowTrail,
        time: Double,
        recovery: Double,
        hold: Double
    ) {
        let axis = end - start
        let axisLengthSquared = dot(axis, axis)
        let crossing = cross(start, end)
        let side = length(crossing) > 1e-9 ? normalize(crossing) : Self.tangent(at: start)
        let startWidth = trail.halfWidth(at: distances.0)
        let widthChange = trail.halfWidth(at: distances.1) - startWidth
        let startOffset = trail.offset(at: distances.0)
        let offsetChange = trail.offset(at: distances.1) - startOffset
        let reach = axisLengthSquared.squareRoot() / 2 + trail.reach
        paint(around: normalize(start + end), reach: reach, time: time, recovery: recovery, hold: hold) { point in
            let relative = point - start
            let along = axisLengthSquared > 1e-18 ? min(max(dot(relative, axis) / axisLengthSquared, 0), 1) : 0
            let offset = relative - axis * along
            let sideways = dot(offset, side)
            let lateral = sideways - (startOffset + offsetChange * along)
            let lengthwise = max(dot(offset, offset) - sideways * sideways, 0)
            let distance = (lateral * lateral + lengthwise).squareRoot() / (startWidth + widthChange * along)
            guard distance < 1 else { return 0 }
            let rest = 1 - distance
            return rest * rest * rest.squareRoot()
        }
    }

    private func paint(
        around center: SIMD3<Double>,
        reach: Double,
        time: Double,
        recovery: Double,
        hold: Double,
        strength: (SIMD3<Double>) -> Double
    ) {
        let width = Self.width
        let latitude = asin(min(max(center.y, -1), 1))
        let longitude = atan2(center.x, center.z)
        let centerRow = (0.5 - latitude / .pi) * Double(Self.height) - 0.5
        let centerColumn = Int(((longitude / (2 * .pi)) + 0.5) * Double(width))
        let rowReach = reach / .pi * Double(Self.height) + 1
        let first = max(Int(floor(centerRow - rowReach)), 0)
        let last = min(Int(ceil(centerRow + rowReach)), Self.height - 1)
        guard first <= last else { return }
        let columnReach = min(Int(reach / (2 * .pi) * Double(width) / max(cos(latitude) - sin(reach), 0.02)) + 2, width / 2)
        let firstColumn = ((centerColumn - columnReach) % width + width) % width
        let limit = cos(reach)
        let peak = time + hold
        let span = recovery + hold
        stamps.withUnsafeMutableBufferPointer { values in
            for row in first...last {
                let ring = rowRings[row]
                let height = rowHeights[row]
                let rowStart = row * width
                for step in 0...(2 * columnReach) {
                    var column = firstColumn + step
                    if column >= width {
                        column -= width
                    }
                    let point = SIMD3(ring * columnSines[column], height, ring * columnCosines[column])
                    guard dot(point, center) > limit else { continue }
                    let amount = strength(point)
                    guard amount > 0 else { continue }
                    let value = Float16(peak - (1 - amount) * span)
                    if value > values[rowStart + column] {
                        values[rowStart + column] = value
                    }
                }
            }
        }
        markDirty(rows: first...last, columns: (centerColumn - columnReach)...(centerColumn + columnReach))
    }

    private func clock(at now: Date, recovery: Double) -> Double {
        let time = now.timeIntervalSince(epoch)
        guard time > Self.rebaseAge else { return time }
        epoch = now
        guard let rows = disturbedRows else { return 0 }
        stamps.withUnsafeMutableBufferPointer { values in
            for index in (rows.lowerBound * Self.width)..<((rows.upperBound + 1) * Self.width) {
                let shifted = Double(values[index]) - time
                values[index] = shifted > -recovery ? Float16(shifted) : Self.settled
            }
        }
        markDirty(rows: rows, columns: 0...(Self.width - 1))
        return 0
    }

    private func settle(rows: ClosedRange<Int>) {
        stamps.withUnsafeMutableBufferPointer { values in
            for index in (rows.lowerBound * Self.width)..<((rows.upperBound + 1) * Self.width) {
                values[index] = Self.settled
            }
        }
    }

    private func markDirty(rows: ClosedRange<Int>, columns: ClosedRange<Int>) {
        dirtyRows = Self.union(dirtyRows, rows)
        dirtyColumns = Self.union(dirtyColumns, columns)
        disturbedRows = Self.union(disturbedRows, rows)
    }

    private func flush() {
        guard let rows = dirtyRows, let columns = dirtyColumns else { return }
        dirtyRows = nil
        dirtyColumns = nil
        if columns.lowerBound >= 0 && columns.upperBound < Self.width {
            upload(rows: rows, columns: columns)
        } else {
            upload(rows: rows, columns: 0...(Self.width - 1))
        }
    }

    private func upload(rows: ClosedRange<Int>, columns: ClosedRange<Int>) {
        let stride = MemoryLayout<Float16>.stride
        stamps.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            texture.replace(
                region: MTLRegionMake2D(columns.lowerBound, rows.lowerBound, columns.count, rows.count),
                mipmapLevel: 0,
                withBytes: base + (rows.lowerBound * Self.width + columns.lowerBound) * stride,
                bytesPerRow: Self.width * stride
            )
        }
    }

    private static func union(_ range: ClosedRange<Int>?, _ other: ClosedRange<Int>) -> ClosedRange<Int> {
        guard let range else { return other }
        return min(range.lowerBound, other.lowerBound)...max(range.upperBound, other.upperBound)
    }

    private static func tangent(at direction: SIMD3<Double>) -> SIMD3<Double> {
        let helper: SIMD3<Double> = abs(direction.y) < 0.9 ? SIMD3(0, 1, 0) : SIMD3(1, 0, 0)
        return normalize(cross(helper, direction))
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
