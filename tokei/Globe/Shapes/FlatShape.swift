enum FlatShape {
    static func lift(_ field: TerrainField) -> TerrainLift {
        let level = [Float](repeating: 0, count: field.width * field.height)
        return TerrainLift(heights: level, relief: level)
    }
}
