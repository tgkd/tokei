import Foundation

enum SteppedShape {
    static let thresholds: [Float] = [35, 70, 105, 140, 175, 215].map { $0 / 255 }
    private static let softness: Float = 3 / 255
    private static let base = 0.01
    private static let rise: Float = 0.006
    private static let cliff = 0.2

    static func lift(_ field: TerrainField) -> TerrainLift {
        let count = field.width * field.height
        let elevation = field.elevation().map { field.blurred($0, sigma: 0.35) } ?? [Float](repeating: 0, count: count)
        let inland = Self.inland(field)
        let levels = Float(thresholds.count)
        var heights = [Float](repeating: 0, count: count)
        var relief = [Float](repeating: 0, count: count)
        var index = 0
        while index < count {
            var level: Float = 0
            for threshold in thresholds {
                level += ToyTerrain.smoothstep(threshold - softness, threshold + softness, elevation[index])
            }
            let lifted = level * inland[index]
            heights[index] = rise * lifted
            relief[index] = lifted / levels
            index += 1
        }
        let profile = TerrainProfile(
            height: { base * TerrainProfile.smoothstep(0, cliff, $0) },
            relief: { _ in 0 }
        )
        return TerrainLift(heights: heights, relief: relief, profile: profile)
    }

    static func inland(_ field: TerrainField) -> [Float] {
        ToyTerrain.smoothstep(0.1, 0.5, field.distance)
    }
}
