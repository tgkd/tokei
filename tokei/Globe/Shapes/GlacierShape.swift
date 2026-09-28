import Foundation
import simd

enum GlacierShape {
    private static let cliff = 0.25
    private static let shelf = 0.6

    static func lift(_ field: TerrainField) -> TerrainLift {
        let peak = Float(ToyTerrain.plateHeight)
        let land = ToyTerrain.smoothstep(0.5, 0.9, field.blurred(field.coverage, sigma: 0.8))
        let plateau = ToyTerrain.smoothstep(0.55, 0.62, field.blurred(field.coverage, sigma: 3))
        let inland = ToyTerrain.smoothstep(0.1, 0.6, field.distance)
        var rises = [Float](repeating: 0, count: field.width * field.height)
        var summits = [Float](repeating: 0, count: field.width * field.height)
        for range in MountainRange.iconic.map({ $0.carve() }) {
            let angle = acos(min(max(range.reach, -1), 1))
            let latitude = asin(min(max(range.center.y, -1), 1))
            let longitude = atan2(range.center.x, range.center.z)
            let rowStep = Double.pi / Double(field.height)
            let columnStep = 2 * Double.pi / Double(field.width)
            let top = max(Int(((.pi / 2 - latitude - angle) / rowStep).rounded(.down)), 0)
            let bottom = min(Int(((.pi / 2 - latitude + angle) / rowStep).rounded(.up)), field.height - 1)
            let widest = abs(latitude) + angle
            let spread = widest >= .pi / 2 - 0.01 ? Double.pi : min(angle / cos(widest), .pi)
            let first = Int(((longitude - spread + .pi) / columnStep).rounded(.down))
            let last = Int(((longitude + spread + .pi) / columnStep).rounded(.up))
            var row = top
            while row <= bottom {
                var offset = first
                while offset <= last {
                    let column = ((offset % field.width) + field.width) % field.width
                    let rise = range.height(at: field.direction(column: column, row: row))
                    if rise > 0 {
                        let cell = row * field.width + column
                        rises[cell] = max(rises[cell], Float(rise))
                        summits[cell] = max(summits[cell], Float(rise / range.tallest))
                    }
                    offset += 1
                }
                row += 1
            }
        }
        var heights = [Float](repeating: 0, count: field.width * field.height)
        var relief = [Float](repeating: 0, count: field.width * field.height)
        var index = 0
        while index < heights.count {
            let tier = Float(1 - shelf) * plateau[index] * inland[index]
            heights[index] = peak * tier + rises[index] * land[index]
            relief[index] = tier + summits[index] * land[index]
            index += 1
        }
        let profile = TerrainProfile(
            height: { Double(peak) * shelf * TerrainProfile.smoothstep(0, cliff, $0) },
            relief: { shelf * TerrainProfile.smoothstep(0, cliff, $0) }
        )
        return TerrainLift(heights: heights, relief: relief, profile: profile)
    }
}
