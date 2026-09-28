import Foundation
import simd

struct TerrainNode {
    let face: Int
    let level: Int
    let column: Int
    let row: Int

    static let roots = (0..<6).map { TerrainNode(face: $0, level: 0, column: 0, row: 0) }

    var size: Double {
        2 / Double(1 << level)
    }

    var radius: Double {
        0.82 * size * .pi / 4
    }

    var index: Int {
        6 * ((1 << (2 * level)) - 1) / 3 + (face << (2 * level)) + (row << level) + column
    }

    var packed: UInt32 {
        UInt32(face) << 28 | UInt32(level) << 24 | UInt32(column) << 12 | UInt32(row)
    }

    func child(_ corner: Int) -> TerrainNode {
        TerrainNode(face: face, level: level + 1, column: column * 2 + corner % 2, row: row * 2 + corner / 2)
    }

    func child(containing a: Double, _ b: Double) -> TerrainNode {
        let count = 2 << level
        let span = 2 / Double(count)
        return TerrainNode(
            face: face,
            level: level + 1,
            column: min(max(Int(floor((a + 1) / span)), 0), count - 1),
            row: min(max(Int(floor((b + 1) / span)), 0), count - 1)
        )
    }

    func cell(grid: Int) -> Double {
        1.15 * size * .pi / 4 / Double(grid)
    }

    func point(_ i: Int, _ j: Int, grid: Int) -> (a: Double, b: Double) {
        (-1 + size * (Double(column) + Double(i) / Double(grid)), -1 + size * (Double(row) + Double(j) / Double(grid)))
    }
}

final class TerrainTree {
    static let detailWidth = 128
    static let detailHeight = 64

    private let entries: [SIMD4<Float>]
    private let detailCells: [Int32]

    init(coast: TerrainGrid, depth: Int) {
        let count = 6 * ((1 << (2 * (depth + 1))) - 1) / 3
        var entries = [SIMD4<Float>](repeating: .zero, count: count)
        var detailCells = [Int32](repeating: 0, count: count)
        var level = 0
        while level <= depth {
            let side = 1 << level
            var face = 0
            while face < 6 {
                var row = 0
                while row < side {
                    var column = 0
                    while column < side {
                        let node = TerrainNode(face: face, level: level, column: column, row: row)
                        let a = -1 + node.size * (Double(column) + 0.5)
                        let b = -1 + node.size * (Double(row) + 0.5)
                        let center = Self.direction(face: face, a: a, b: b)
                        let distance = coast.sample(center)
                        entries[node.index] = SIMD4(Float(center.x), Float(center.y), Float(center.z), Float(distance))
                        detailCells[node.index] = Int32(Self.detailCell(center))
                        column += 1
                    }
                    row += 1
                }
                face += 1
            }
            level += 1
        }
        self.entries = entries
        self.detailCells = detailCells
    }

    func entry(_ node: TerrainNode) -> SIMD4<Float> {
        entries[node.index]
    }

    func detailCell(_ node: TerrainNode) -> Int {
        Int(detailCells[node.index])
    }

    static func detailCell(_ direction: SIMD3<Double>) -> Int {
        let longitude = atan2(direction.x, direction.z)
        let latitude = asin(min(max(direction.y, -1), 1))
        let column = min(max(Int((longitude / (2 * .pi) + 0.5) * Double(detailWidth)), 0), detailWidth - 1)
        let row = min(max(Int((0.5 - latitude / .pi) * Double(detailHeight)), 0), detailHeight - 1)
        return row * detailWidth + column
    }

    static func direction(face: Int, a: Double, b: Double) -> SIMD3<Double> {
        let u = tangent(a)
        let v = tangent(b)
        let x: Double
        let y: Double
        let z: Double
        switch face {
        case 0:
            (x, y, z) = (1, u, v)
        case 1:
            (x, y, z) = (-1, v, u)
        case 2:
            (x, y, z) = (v, 1, u)
        case 3:
            (x, y, z) = (u, -1, v)
        case 4:
            (x, y, z) = (u, v, 1)
        default:
            (x, y, z) = (v, u, -1)
        }
        let length = (x * x + y * y + z * z).squareRoot()
        return SIMD3(x / length, y / length, z / length)
    }

    static func faceCoordinates(_ direction: SIMD3<Double>) -> (face: Int, a: Double, b: Double) {
        let x = direction.x
        let y = direction.y
        let z = direction.z
        let face: Int
        let u: Double
        let v: Double
        let depth: Double
        if abs(x) >= abs(y) && abs(x) >= abs(z) {
            face = x > 0 ? 0 : 1
            depth = abs(x)
            (u, v) = x > 0 ? (y, z) : (z, y)
        } else if abs(y) >= abs(z) {
            face = y > 0 ? 2 : 3
            depth = abs(y)
            (u, v) = y > 0 ? (z, x) : (x, z)
        } else {
            face = z > 0 ? 4 : 5
            depth = abs(z)
            (u, v) = z > 0 ? (x, y) : (y, x)
        }
        return (face, atan(u / depth) / (.pi / 4), atan(v / depth) / (.pi / 4))
    }

    private static func tangent(_ parameter: Double) -> Double {
        if abs(parameter) == 1 {
            return parameter
        }
        return tan(parameter * .pi / 4)
    }
}
