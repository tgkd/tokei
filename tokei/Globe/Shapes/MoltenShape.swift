enum MoltenShape {
    static let bevel: Float = 0.5
    static let plateau: Float = 0.82

    static func lift(_ field: TerrainField) -> TerrainLift {
        let peak = Float(ToyTerrain.plateHeight)
        let swell = field.blurred(field.coverage, sigma: 2.5)
        let heights = zip(field.distance, swell).map { distance, swell in
            peak * ToyTerrain.smoothstep(0, bevel, distance) * (plateau + (1 - plateau) * ToyTerrain.smoothstep(0.5, 1, swell))
        }
        return TerrainLift(heights: heights, relief: heights.map { $0 / peak })
    }
}
