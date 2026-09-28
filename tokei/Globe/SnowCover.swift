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
    static let width = 1024
    static let height = 512
    private static let settled = Float16(-1000)

    let texture: MTLTexture
    private(set) var epoch = Date()
    private var stamps: [Float16]
    private let columnSines: [Double]
    private let columnCosines: [Double]

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
        upload(rows: 0..<Self.height)
    }

    func stamp(at direction: SIMD3<Double>, shape: FootprintShape, recovery: Double, now: Date) {
        let time = now.timeIntervalSince(epoch)
        let reach = shape.reach
        let latitude = asin(min(max(direction.y, -1), 1))
        let longitude = atan2(direction.x, direction.z)
        let centerRow = (0.5 - latitude / .pi) * Double(Self.height) - 0.5
        let centerColumn = Int(((longitude / (2 * .pi)) + 0.5) * Double(Self.width))
        let rowReach = reach / .pi * Double(Self.height) + 1
        let first = max(Int(floor(centerRow - rowReach)), 0)
        let last = min(Int(ceil(centerRow + rowReach)), Self.height - 1)
        guard first <= last else { return }
        let helper: SIMD3<Double> = abs(direction.y) < 0.9 ? SIMD3(0, 1, 0) : SIMD3(1, 0, 0)
        let east = normalize(cross(helper, direction))
        let north = cross(direction, east)
        let limit = cos(reach)
        let columnReach = min(Int(reach / (2 * .pi) * Double(Self.width) / max(cos(latitude) - sin(reach), 0.02)) + 2, Self.width / 2)
        for row in first...last {
            let rowLatitude = (0.5 - (Double(row) + 0.5) / Double(Self.height)) * .pi
            let ring = cos(rowLatitude)
            let height = sin(rowLatitude)
            for offset in -columnReach...columnReach {
                let column = ((centerColumn + offset) % Self.width + Self.width) % Self.width
                let point = SIMD3(ring * columnSines[column], height, ring * columnCosines[column])
                guard dot(point, direction) > limit else { continue }
                let distance = shape.normalizedDistance(SIMD2(dot(point, east), dot(point, north)))
                guard distance < 1 else { continue }
                let strength = 1 - Self.smoothstep(0.55, 1, distance)
                let value = Float16(time - (1 - strength) * recovery)
                let index = row * Self.width + column
                if value > stamps[index] {
                    stamps[index] = value
                }
            }
        }
        upload(rows: first..<(last + 1))
    }

    func reset() {
        stamps = [Float16](repeating: Self.settled, count: Self.width * Self.height)
        epoch = Date()
        upload(rows: 0..<Self.height)
    }

    private func upload(rows: Range<Int>) {
        let rowBytes = Self.width * MemoryLayout<Float16>.stride
        stamps.withUnsafeBytes { bytes in
            texture.replace(
                region: MTLRegionMake2D(0, rows.lowerBound, Self.width, rows.count),
                mipmapLevel: 0,
                withBytes: bytes.baseAddress! + rows.lowerBound * rowBytes,
                bytesPerRow: rowBytes
            )
        }
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
