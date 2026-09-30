import Foundation
import simd

struct TerrainField {
    let width: Int
    let height: Int
    let degree: Double
    let coverage: [Float]
    let distance: [Float]
    let elevationURL: URL?

    func direction(column: Int, row: Int) -> SIMD3<Double> {
        ToyTerrain.direction(column: column, row: row, width: width, height: height)
    }

    func blurred(_ values: [Float], sigma degrees: Double) -> [Float] {
        ToyTerrain.blur(values, width: width, height: height, sigma: degrees * degree)
    }

    func elevation() -> [Float]? {
        elevationURL.flatMap { ToyTerrain.decodeElevation(url: $0, width: width, height: height) }
    }
}

struct TerrainLift {
    var heights: [Float]
    var relief: [Float]
    var profile: TerrainProfile?
}

enum ToyShape: CaseIterable {
    case puffy
    case molten
    case terraced
    case stepped

    func lift(_ field: TerrainField) -> TerrainLift {
        switch self {
        case .puffy: PuffyShape.lift(field)
        case .molten: MoltenShape.lift(field)
        case .terraced: TerracedShape.lift(field)
        case .stepped: SteppedShape.lift(field)
        }
    }
}
