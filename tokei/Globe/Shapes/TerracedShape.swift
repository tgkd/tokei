import simd

enum TerracedShape {
    static let landRise = Float(ToyTerrain.plateHeight) / 5
    static let seaDrop: Float = 0.0008
    static let softness: Float = 0.3

    private static let waveCount = 15
    private static let bendCell = 2.0

    static func lift(_ field: TerrainField) -> TerrainLift {
        let look = PaperLook.standard
        let landSteps = [0, look.landSteps.x, look.landSteps.y, look.landSteps.z, look.landSteps.w]
        let seaSteps = [look.seaSteps.x, look.seaSteps.y, look.seaSteps.z, look.seaSteps.w]
        let bends = bendField(field)
        var heights = [Float](repeating: 0, count: field.width * field.height)
        for index in heights.indices {
            let tier = field.distance[index] * (1 + look.contourWobble * bends[index])
            var height: Float = 0
            for step in landSteps {
                height += landRise * smoothstep(step - softness, step + softness, tier)
            }
            for step in seaSteps {
                height -= seaDrop * (1 - smoothstep(step - softness, step + softness, tier))
            }
            heights[index] = height
        }
        return TerrainLift(heights: heights, relief: bends)
    }

    private static func bend(_ direction: SIMD3<Double>) -> Float {
        let golden = Double.pi * (3 - 5.0.squareRoot())
        var sum = 0.0
        for index in 0..<waveCount {
            let z = 1 - (2 * Double(index) + 1) / Double(waveCount)
            let radius = (1 - z * z).squareRoot()
            let angle = golden * Double(index)
            let axis = SIMD3(radius * cos(angle), radius * sin(angle), z)
            let frequency = [8.0, 13.0, 21.0][index % 3]
            let phase = 2 * Double.pi * (Double(index) * 0.618_034).truncatingRemainder(dividingBy: 1)
            sum += sin(frequency * dot(axis, direction) + phase)
        }
        let spread = sum / (Double(waveCount) / 2).squareRoot()
        return Float(min(max(0.6 * spread, -1), 1))
    }

    private static func bendField(_ field: TerrainField) -> [Float] {
        let step = max(Int((bendCell * field.degree).rounded()), 1)
        let columns = max(field.width / step, 1)
        let rows = field.height / step + 1
        var coarse = [Float](repeating: 0, count: columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                coarse[row * columns + column] = bend(field.direction(column: column * step, row: min(row * step, field.height - 1)))
            }
        }
        var result = [Float](repeating: 0, count: field.width * field.height)
        for row in 0..<field.height {
            let y = Float(row) / Float(step)
            let top = min(Int(y), rows - 1)
            let bottom = min(top + 1, rows - 1)
            let fy = smoothstep(0, 1, y - Float(top))
            for column in 0..<field.width {
                let x = Float(column) / Float(step)
                let left = Int(x) % columns
                let right = (left + 1) % columns
                let fx = smoothstep(0, 1, x - Float(Int(x)))
                let upper = coarse[top * columns + left] * (1 - fx) + coarse[top * columns + right] * fx
                let lower = coarse[bottom * columns + left] * (1 - fx) + coarse[bottom * columns + right] * fx
                result[row * field.width + column] = upper * (1 - fy) + lower * fy
            }
        }
        return result
    }

    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
