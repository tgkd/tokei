import Accelerate

enum PuffyShape {
    static func lift(_ field: TerrainField) -> TerrainLift {
        let peak = ToyTerrain.plateHeight
        let bevel = 1.0
        let rim = 0.55
        let puff = ToyTerrain.smoothstep(0.5, 1, field.blurred(field.coverage, sigma: 2.2))
        let inland = ToyTerrain.smoothstep(0, 1.2, field.distance)
        let count = vDSP_Length(puff.count)
        var dome = [Float](repeating: 0, count: puff.count)
        var heights = [Float](repeating: 0, count: puff.count)
        var relief = [Float](repeating: 0, count: puff.count)
        var heightScale = Float(peak * (1 - rim))
        var reliefScale = Float(1 - rim)
        vDSP_vmul(puff, 1, inland, 1, &dome, 1, count)
        vDSP_vsmul(dome, 1, &heightScale, &heights, 1, count)
        vDSP_vsmul(dome, 1, &reliefScale, &relief, 1, count)
        let profile = TerrainProfile(
            height: { peak * rim * pillow($0 / bevel) },
            relief: { rim * pillow($0 / bevel) }
        )
        return TerrainLift(heights: heights, relief: relief, profile: profile)
    }

    private static func pillow(_ t: Double) -> Double {
        let clamped = min(max(t, 0), 1)
        return 1 - pow(1 - clamped, 2.5) * (1 + 2.5 * clamped)
    }
}
