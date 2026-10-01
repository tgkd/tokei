import Foundation
import Metal
import simd

enum MarkBrush: Equatable {
    case stitches(dash: Double, gap: Double)
}

struct MarkSettings: Equatable {
    var drag: MarkBrush
    var width: Double
}

struct MarkStroke {
    let halfWidth: Double
    var last: SIMD3<Double>?
    var distance = 0.0
}

@MainActor
final class MarkMap {
    static let width = 2048
    static let height = 1024
    private static let minimumStep = 0.6
    private static let overlap = 0.5

    let texture: MTLTexture
    private(set) var revision = 0
    private var coverage: [Float16]
    private var phase: [Float16]
    private let columnSines: [Double]
    private let columnCosines: [Double]
    private let rowRings: [Double]
    private let rowHeights: [Double]
    private var dirtyRows: ClosedRange<Int>?
    private var dirtyColumns: ClosedRange<Int>?
    private var touchedRows: ClosedRange<Int>?

    init?(device: MTLDevice) {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rg16Float, width: Self.width, height: Self.height, mipmapped: false)
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        self.texture = texture
        coverage = [Float16](repeating: 0, count: Self.width * Self.height)
        phase = [Float16](repeating: 0, count: Self.width * Self.height)
        let longitudes = (0..<Self.width).map { ((Double($0) + 0.5) / Double(Self.width) - 0.5) * 2 * .pi }
        columnSines = longitudes.map(sin)
        columnCosines = longitudes.map(cos)
        let latitudes = (0..<Self.height).map { (0.5 - (Double($0) + 0.5) / Double(Self.height)) * .pi }
        rowRings = latitudes.map(cos)
        rowHeights = latitudes.map(sin)
        upload(rows: 0...(Self.height - 1), columns: 0...(Self.width - 1))
    }

    func sweep(to point: SIMD3<Double>, stroke: inout MarkStroke, brush: MarkBrush) {
        guard let last = stroke.last else {
            stroke.last = point
            return
        }
        let arc = acos(min(max(dot(last, point), -1), 1))
        guard arc >= stroke.halfWidth * Self.minimumStep else { return }
        let pieces = max(Int((arc / (stroke.halfWidth * 0.5)).rounded(.up)), 1)
        let pieceArc = arc / Double(pieces)
        var from = last
        for piece in 1...pieces {
            let fraction = Double(piece) / Double(pieces)
            let to = piece == pieces ? point : normalize(last + (point - last) * fraction)
            paintPiece(from: from, to: to, distance: stroke.distance + arc * Double(piece - 1) / Double(pieces), pieceArc: pieceArc, halfWidth: stroke.halfWidth, brush: brush)
            from = to
        }
        stroke.distance += arc
        stroke.last = point
        flush()
        revision += 1
    }

    func reset() {
        guard let rows = touchedRows else { return }
        touchedRows = nil
        clear(rows: rows)
        upload(rows: rows, columns: 0...(Self.width - 1))
        revision += 1
    }

    private func paintPiece(from start: SIMD3<Double>, to end: SIMD3<Double>, distance: Double, pieceArc: Double, halfWidth: Double, brush: MarkBrush) {
        let axis = end - start
        let axisLengthSquared = dot(axis, axis)
        let crossing = cross(start, end)
        let side = length(crossing) > 1e-9 ? normalize(crossing) : Self.tangent(at: start)
        let spill = halfWidth * Self.overlap / max(axisLengthSquared.squareRoot(), 1e-9)
        let reach = axisLengthSquared.squareRoot() / 2 + halfWidth * (1 + Self.overlap)
        paint(around: normalize(start + end), reach: reach) { point in
            guard axisLengthSquared > 1e-18 else { return (0, 0) }
            let relative = point - start
            let along = dot(relative, axis) / axisLengthSquared
            guard along >= -spill, along <= 1 + spill else { return (0, 0) }
            let offset = relative - axis * along
            let across = dot(offset, side) / halfWidth
            guard abs(across) < 1 else { return (0, 0) }
            var amount = (1 - Self.smoothstep(0.8, 1, abs(across))) * Self.smoothstep(-spill, 0, along)
            switch brush {
            case .stitches(let dash, let gap):
                let s = distance + along * pieceArc
                let period = (dash + gap) * halfWidth
                let u = s.truncatingRemainder(dividingBy: period)
                amount *= Self.smoothstep(0, 0.25 * halfWidth, u) * (1 - Self.smoothstep(dash * halfWidth - 0.25 * halfWidth, dash * halfWidth, u))
            }
            return (amount, across)
        }
    }

    private func paint(around center: SIMD3<Double>, reach: Double, strength: (SIMD3<Double>) -> (Double, Double)) {
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
        coverage.withUnsafeMutableBufferPointer { cover in
            phase.withUnsafeMutableBufferPointer { phases in
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
                        let (amount, value) = strength(point)
                        guard amount > 0 else { continue }
                        let index = rowStart + column
                        let oldCoverage = Double(cover[index])
                        let newCoverage = amount + (1 - amount) * oldCoverage
                        cover[index] = Float16(newCoverage)
                        let oldPhase = Double(phases[index])
                        phases[index] = Float16(amount * value + (1 - amount) * oldPhase)
                    }
                }
            }
        }
        markDirty(rows: first...last, columns: (centerColumn - columnReach)...(centerColumn + columnReach))
    }

    private func clear(rows: ClosedRange<Int>) {
        coverage.withUnsafeMutableBufferPointer { cover in
            phase.withUnsafeMutableBufferPointer { phases in
                for index in (rows.lowerBound * Self.width)..<((rows.upperBound + 1) * Self.width) {
                    cover[index] = 0
                    phases[index] = 0
                }
            }
        }
    }

    private func markDirty(rows: ClosedRange<Int>, columns: ClosedRange<Int>) {
        dirtyRows = Self.union(dirtyRows, rows)
        dirtyColumns = Self.union(dirtyColumns, columns)
        touchedRows = Self.union(touchedRows, rows)
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
        let width = Self.width
        let pixelStride = 2 * MemoryLayout<Float16>.stride
        var interleaved = [Float16](repeating: 0, count: rows.count * width * 2)
        coverage.withUnsafeBufferPointer { cover in
            phase.withUnsafeBufferPointer { phases in
                for row in rows {
                    let sourceBase = row * width
                    let targetBase = (row - rows.lowerBound) * width * 2
                    for column in 0..<width {
                        let source = sourceBase + column
                        let target = targetBase + column * 2
                        interleaved[target] = cover[source]
                        interleaved[target + 1] = phases[source]
                    }
                }
            }
        }
        interleaved.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            texture.replace(
                region: MTLRegionMake2D(columns.lowerBound, rows.lowerBound, columns.count, rows.count),
                mipmapLevel: 0,
                withBytes: base + columns.lowerBound * pixelStride,
                bytesPerRow: width * pixelStride
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
