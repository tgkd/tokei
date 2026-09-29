import Metal
import simd

struct CloudShell {
    static let height = 0.045
    static let floor = 0.012
    static let cells = 48

    let directions: MTLBuffer
    let indices: MTLBuffer
    let indexCount: Int

    static func lift(inflate: Double) -> Double {
        max(height * inflate, floor)
    }

    static var uniforms: SIMD4<Float> {
        SIMD4(Float(height), Float(floor), 0, 0)
    }

    init?(device: MTLDevice) {
        let normals: [SIMD3<Float>] = [SIMD3(1, 0, 0), SIMD3(-1, 0, 0), SIMD3(0, 1, 0), SIMD3(0, -1, 0), SIMD3(0, 0, 1), SIMD3(0, 0, -1)]
        let us: [SIMD3<Float>] = [SIMD3(0, 1, 0), SIMD3(0, 0, 1), SIMD3(0, 0, 1), SIMD3(1, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0)]
        let vs: [SIMD3<Float>] = [SIMD3(0, 0, 1), SIMD3(0, 1, 0), SIMD3(1, 0, 0), SIMD3(0, 0, 1), SIMD3(0, 1, 0), SIMD3(1, 0, 0)]
        let side = Self.cells + 1
        var points: [Float] = []
        points.reserveCapacity(6 * side * side * 3)
        var indices: [UInt16] = []
        indices.reserveCapacity(6 * Self.cells * Self.cells * 6)
        for face in 0..<6 {
            let base = face * side * side
            for j in 0..<side {
                for i in 0..<side {
                    let a = tan((-1 + 2 * Float(i) / Float(Self.cells)) * .pi / 4)
                    let b = tan((-1 + 2 * Float(j) / Float(Self.cells)) * .pi / 4)
                    let direction = normalize(normals[face] + us[face] * a + vs[face] * b)
                    points.append(contentsOf: [direction.x, direction.y, direction.z])
                }
            }
            for j in 0..<Self.cells {
                for i in 0..<Self.cells {
                    let corner = UInt16(base + j * side + i)
                    let right = corner + 1
                    let above = corner + UInt16(side)
                    let diagonal = above + 1
                    indices.append(contentsOf: [corner, right, diagonal, corner, diagonal, above])
                }
            }
        }
        guard
            let directions = points.withUnsafeBytes({ device.makeBuffer(bytes: $0.baseAddress!, length: $0.count) }),
            let indexBuffer = indices.withUnsafeBytes({ device.makeBuffer(bytes: $0.baseAddress!, length: $0.count) })
        else { return nil }
        self.directions = directions
        self.indices = indexBuffer
        indexCount = indices.count
    }
}
