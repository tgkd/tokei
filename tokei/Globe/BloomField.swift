import Foundation
import Metal
import simd

struct BloomTiming: Equatable {
    var grow: Double
    var hold: Double
    var hide: Double
    var stagger: Double

    var span: Double {
        grow + hold + hide + stagger
    }
}

struct BloomSettings: Equatable {
    var timing: BloomTiming
    var width: Double
    var tuft: Double
    var pop: Double
    var minimumWidth: Double
    var minimumTuft: Double
}

struct BloomStroke {
    let halfWidth: Double
    var last: SIMD3<Double>?
}

@MainActor
final class BloomField {
    static let width = 1024
    static let height = 512
    private static let settled = Float16(-1000)
    private static let rebaseAge = 64.0
    private static let minimumStep = 0.3

    let texture: MTLTexture
    private(set) var epoch = Date()
    private var times: [Float16]
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
        times = [Float16](repeating: Self.settled, count: Self.width * Self.height * 2)
        let longitudes = (0..<Self.width).map { ((Double($0) + 0.5) / Double(Self.width) - 0.5) * 2 * .pi }
        columnSines = longitudes.map(sin)
        columnCosines = longitudes.map(cos)
        let latitudes = (0..<Self.height).map { (0.5 - (Double($0) + 0.5) / Double(Self.height)) * .pi }
        rowRings = latitudes.map(cos)
        rowHeights = latitudes.map(sin)
        upload(rows: 0...(Self.height - 1), columns: 0...(Self.width - 1))
    }

    func stamp(at center: SIMD3<Double>, radius: Double, timing: BloomTiming, now: Date) {
        let time = clock(at: now, timing: timing)
        paint(around: center, reach: radius, time: time, timing: timing) { _ in true }
        flush()
    }

    func sweep(to point: SIMD3<Double>, stroke: inout BloomStroke, timing: BloomTiming, now: Date) {
        guard let last = stroke.last else {
            stroke.last = point
            stamp(at: point, radius: stroke.halfWidth, timing: timing, now: now)
            return
        }
        let arc = acos(min(max(dot(last, point), -1), 1))
        guard arc >= stroke.halfWidth * Self.minimumStep else { return }
        let time = clock(at: now, timing: timing)
        let pieces = max(Int((arc / (stroke.halfWidth * 0.5)).rounded(.up)), 1)
        var from = last
        for piece in 1...pieces {
            let to = piece == pieces ? point : normalize(last + (point - last) * (Double(piece) / Double(pieces)))
            paintPiece(from: from, to: to, halfWidth: stroke.halfWidth, time: time, timing: timing)
            from = to
        }
        stroke.last = point
        flush()
    }

    func reset() {
        epoch = Date()
        guard let rows = touchedRows else { return }
        touchedRows = nil
        settle(rows: rows)
        upload(rows: rows, columns: 0...(Self.width - 1))
    }

    private func paintPiece(from start: SIMD3<Double>, to end: SIMD3<Double>, halfWidth: Double, time: Double, timing: BloomTiming) {
        let axis = end - start
        let axisLengthSquared = dot(axis, axis)
        let limit = halfWidth * halfWidth
        let reach = axisLengthSquared.squareRoot() / 2 + halfWidth
        paint(around: normalize(start + end), reach: reach, time: time, timing: timing) { point in
            let relative = point - start
            let along = axisLengthSquared > 1e-18 ? min(max(dot(relative, axis) / axisLengthSquared, 0), 1) : 0
            let offset = relative - axis * along
            return dot(offset, offset) < limit
        }
    }

    private func paint(around center: SIMD3<Double>, reach: Double, time: Double, timing: BloomTiming, inside: (SIMD3<Double>) -> Bool) {
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
        times.withUnsafeMutableBufferPointer { values in
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
                    guard dot(point, center) > limit, inside(point) else { continue }
                    let index = (rowStart + column) * 2
                    let renewed = Self.renewed(birth: Double(values[index]), fade: Double(values[index + 1]), at: time, timing: timing)
                    values[index] = Float16(renewed.birth)
                    values[index + 1] = Float16(renewed.fade)
                }
            }
        }
        markDirty(rows: first...last, columns: (centerColumn - columnReach)...(centerColumn + columnReach))
    }

    private static func renewed(birth: Double, fade: Double, at time: Double, timing: BloomTiming) -> (birth: Double, fade: Double) {
        if time < fade + timing.stagger {
            return (birth, max(fade, max(time, birth + timing.grow) + timing.hold))
        }
        let level = 1 - min((time - fade - timing.stagger) / timing.hide, 1)
        let start = time - timing.grow * level
        return (start, start + timing.grow + timing.hold)
    }

    private func clock(at now: Date, timing: BloomTiming) -> Double {
        let time = now.timeIntervalSince(epoch)
        guard time > Self.rebaseAge else { return time }
        epoch = now
        guard let rows = touchedRows else { return 0 }
        times.withUnsafeMutableBufferPointer { values in
            for index in stride(from: rows.lowerBound * Self.width * 2, to: (rows.upperBound + 1) * Self.width * 2, by: 2) {
                let fade = Double(values[index + 1]) - time
                if fade + timing.hide + timing.stagger > 0 {
                    values[index] = Float16(Double(values[index]) - time)
                    values[index + 1] = Float16(fade)
                } else {
                    values[index] = Self.settled
                    values[index + 1] = Self.settled
                }
            }
        }
        markDirty(rows: rows, columns: 0...(Self.width - 1))
        return 0
    }

    private func settle(rows: ClosedRange<Int>) {
        times.withUnsafeMutableBufferPointer { values in
            for index in (rows.lowerBound * Self.width * 2)..<((rows.upperBound + 1) * Self.width * 2) {
                values[index] = Self.settled
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
        let pixelStride = 2 * MemoryLayout<Float16>.stride
        times.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            texture.replace(
                region: MTLRegionMake2D(columns.lowerBound, rows.lowerBound, columns.count, rows.count),
                mipmapLevel: 0,
                withBytes: base + (rows.lowerBound * Self.width + columns.lowerBound) * pixelStride,
                bytesPerRow: Self.width * pixelStride
            )
        }
    }

    private static func union(_ range: ClosedRange<Int>?, _ other: ClosedRange<Int>) -> ClosedRange<Int> {
        guard let range else { return other }
        return min(range.lowerBound, other.lowerBound)...max(range.upperBound, other.upperBound)
    }
}
