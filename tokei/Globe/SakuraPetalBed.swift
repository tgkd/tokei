import Metal
import simd

struct SakuraBedPetal {
    var from: SIMD4<Float>
    var to: SIMD4<Float>
    var pose: SIMD4<Float>
    var timing: SIMD4<Float>
}

enum SakuraPetalBed {
    static let size = 0.9 * Double.pi / 180
    static let cell = 1.07
    static let perCell = 4
    static let lift = 0.0012
    static let stack = 0.00006
    static let tilt = 25 * Double.pi / 180
    static let aspect: Float = 0.8
    static let axisTurns: Float = 17
    static let raftChance = 0.043
    private static let seed: UInt64 = 0x51A7_AE2B_D3C4_E5F6

    static func build(surface: ToySurface, device: MTLDevice) -> SurfaceObjectSet? {
        var petals: [SakuraBedPetal] = []
        var bounds: [SurfaceBounds] = []
        petals.reserveCapacity(40_000)
        bounds.reserveCapacity(40_000)
        let rows = Int((180 / cell).rounded())
        let rowHeight = 180 / Double(rows)
        for row in 0..<rows {
            let south = -90 + Double(row) * rowHeight
            let columns = max(Int(360 * cos((south + rowHeight / 2) * .pi / 180) / rowHeight), 1)
            let columnWidth = 360 / Double(columns)
            for column in 0..<columns {
                let west = -180 + Double(column) * columnWidth
                guard surface.coast.sample(GeoPoint(latitude: south + rowHeight / 2, longitude: west + columnWidth / 2).unitVector) > -2.2 else { continue }
                var random = Seeded(row: row, column: column)
                for layer in 0..<perCell {
                    let latitude = south + random.next() * rowHeight
                    let longitude = west + random.next() * columnWidth
                    let chance = random.next()
                    let turn = random.next()
                    let lean = random.next()
                    let grow = random.next()
                    let shade = Float(random.next())
                    let pointing = GeoPoint(latitude: latitude, longitude: longitude).unitVector
                    guard chance < density(surface.coast.sample(pointing)) else { continue }
                    let yaw = Float(turn * 2 * .pi)
                    let angle = tilt * lean * lean
                    let scale = size * (0.85 + 0.3 * grow)
                    let axis = 2 * Float.pi * (shade * axisTurns).truncatingRemainder(dividingBy: 1)
                    let dip = sin(angle) * scale * Double(abs(sin(axis)) + aspect * abs(cos(axis)))
                    let level = Double(layer * 4 + (row % 2) * 2 + column % 2)
                    let height = surface.height(along: pointing) + lift + level * stack + dip
                    let rest = SIMD4<Float>(SIMD3<Float>(pointing), Float(1 + height))
                    petals.append(SakuraBedPetal(from: rest, to: rest, pose: SIMD4(yaw, yaw, Float(angle), Float(scale)), timing: SIMD4(0, 0, 0, shade)))
                    bounds.append(SurfaceBounds(center: SIMD3<Float>(pointing), radius: Float(scale * 1.3), extent: Float(height + dip + scale * scale), size: Float(scale * 2)))
                }
            }
        }
        let quad = SurfaceTier(minimumPixels: 0, vertexCount: 4, primitive: .triangleStrip)
        return SurfaceObjectSet(records: petals, bounds: bounds, tiers: [quad], device: device)
    }

    private static func density(_ distance: Double) -> Double {
        let land = TerrainProfile.smoothstep(-0.2, 1.5, distance)
        guard distance > -1.2, distance < 0 else { return land }
        return max(land, raftChance * TerrainProfile.smoothstep(-1.2, -0.7, distance))
    }

    private struct Seeded {
        private var state: UInt64

        init(row: Int, column: Int) {
            state = SakuraPetalBed.seed ^ (UInt64(row) &* 0x9E37_79B9_7F4A_7C15) ^ (UInt64(column) &* 0xC2B2_AE3D_27D4_EB4F)
        }

        mutating func next() -> Double {
            state &+= 0x9E37_79B9_7F4A_7C15
            var mixed = state
            mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
            mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
            mixed ^= mixed >> 31
            return Double(mixed >> 11) / 9_007_199_254_740_992
        }
    }
}
