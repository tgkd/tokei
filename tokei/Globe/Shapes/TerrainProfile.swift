struct TerrainProfile {
    static let start = -0.5
    static let step = 1.0 / 128
    static let count = 1024

    let heights: [Float]
    let relief: [Float]

    init(height: (Double) -> Double, relief: (Double) -> Double) {
        var heights = [Float](repeating: 0, count: Self.count)
        var reliefs = [Float](repeating: 0, count: Self.count)
        var index = 0
        while index < Self.count {
            let distance = Self.start + Double(index) * Self.step
            heights[index] = Float(height(distance))
            reliefs[index] = Float(relief(distance))
            index += 1
        }
        self.heights = heights
        self.relief = reliefs
    }

    static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
