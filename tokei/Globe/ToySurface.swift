import simd

struct ToySurface {
    static let cellsPerFace = 160

    struct Face {
        let normal: SIMD3<Double>
        let u: SIMD3<Double>
        let v: SIMD3<Double>
    }

    static let faces = [
        Face(normal: SIMD3(1, 0, 0), u: SIMD3(0, 1, 0), v: SIMD3(0, 0, 1)),
        Face(normal: SIMD3(-1, 0, 0), u: SIMD3(0, 0, 1), v: SIMD3(0, 1, 0)),
        Face(normal: SIMD3(0, 1, 0), u: SIMD3(0, 0, 1), v: SIMD3(1, 0, 0)),
        Face(normal: SIMD3(0, -1, 0), u: SIMD3(1, 0, 0), v: SIMD3(0, 0, 1)),
        Face(normal: SIMD3(0, 0, 1), u: SIMD3(1, 0, 0), v: SIMD3(0, 1, 0)),
        Face(normal: SIMD3(0, 0, -1), u: SIMD3(0, 1, 0), v: SIMD3(1, 0, 0)),
    ]

    let vertices: [ToyVertex]

    static func direction(on face: Face, i: Int, j: Int) -> SIMD3<Double> {
        let a = -1 + 2 * Double(i) / Double(cellsPerFace)
        let b = -1 + 2 * Double(j) / Double(cellsPerFace)
        return normalize(face.normal + face.u * tangent(a) + face.v * tangent(b))
    }

    func radius(along direction: SIMD3<Double>) -> Double {
        let d = normalize(direction)
        let magnitudes = abs(d)
        let faceIndex: Int
        if magnitudes.x >= magnitudes.y && magnitudes.x >= magnitudes.z {
            faceIndex = d.x > 0 ? 0 : 1
        } else if magnitudes.y >= magnitudes.z {
            faceIndex = d.y > 0 ? 2 : 3
        } else {
            faceIndex = d.z > 0 ? 4 : 5
        }
        let face = Self.faces[faceIndex]
        let depth = dot(d, face.normal)
        let a = atan(dot(d, face.u) / depth) / (.pi / 4)
        let b = atan(dot(d, face.v) / depth) / (.pi / 4)
        let cells = Self.cellsPerFace
        let side = cells + 1
        let gridI = (a + 1) / 2 * Double(cells)
        let gridJ = (b + 1) / 2 * Double(cells)
        let i = min(max(Int(floor(gridI)), 0), cells - 1)
        let j = min(max(Int(floor(gridJ)), 0), cells - 1)
        let corner = faceIndex * side * side + j * side + i
        let p00 = point(corner)
        let p10 = point(corner + 1)
        let p01 = point(corner + side)
        let p11 = point(corner + side + 1)
        let first = Self.radialHit(d, p00, p10, p11)
        let second = Self.radialHit(d, p00, p11, p01)
        if first.inside && !second.inside {
            return first.radius
        }
        if second.inside && !first.inside {
            return second.radius
        }
        return gridI - Double(i) >= gridJ - Double(j) ? first.radius : second.radius
    }

    private func point(_ index: Int) -> SIMD3<Double> {
        let position = vertices[index].position
        return SIMD3(Double(position.x), Double(position.y), Double(position.z))
    }

    private static func tangent(_ parameter: Double) -> Double {
        if abs(parameter) == 1 {
            return parameter
        }
        return tan(parameter * .pi / 4)
    }

    private static func radialHit(_ d: SIMD3<Double>, _ a: SIMD3<Double>, _ b: SIMD3<Double>, _ c: SIMD3<Double>) -> (radius: Double, inside: Bool) {
        let normal = cross(b - a, c - a)
        let denominator = dot(normal, d)
        guard abs(denominator) > 1e-12 else { return (dot(a, d), false) }
        let radius = dot(normal, a) / denominator
        let hit = d * radius
        let tolerance = -1e-9 * dot(normal, normal)
        let inside = dot(cross(b - a, hit - a), normal) >= tolerance
            && dot(cross(c - b, hit - b), normal) >= tolerance
            && dot(cross(a - c, hit - c), normal) >= tolerance
        return (radius, inside)
    }
}
