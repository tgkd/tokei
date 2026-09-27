import CoreGraphics
import Foundation
import simd

struct GlobeFrame: Equatable {
    var camera: OrbitCamera
    var size: CGSize
    var sun: SIMD3<Double>

    static func focalLength(for size: CGSize) -> Double {
        Double(min(size.width, size.height)) * 1.6
    }

    var focalLength: Double {
        Self.focalLength(for: size)
    }

    var center: CGPoint {
        CGPoint(x: size.width / 2, y: camera.centerY)
    }

    var position: SIMD3<Double> {
        camera.position
    }

    var forward: SIMD3<Double> {
        -normalize(position)
    }

    var right: SIMD3<Double> {
        normalize(cross(forward, SIMD3(0, 1, 0)))
    }

    var up: SIMD3<Double> {
        cross(right, forward)
    }

    var globeRadius: Double {
        focalLength / sqrt(max(camera.distance * camera.distance - 1, 1e-6))
    }

    func project(_ point: SIMD3<Double>) -> CGPoint? {
        let offset = point - position
        let depth = dot(offset, forward)
        guard depth > 1e-6 else { return nil }
        return CGPoint(
            x: center.x + focalLength * dot(offset, right) / depth,
            y: center.y - focalLength * dot(offset, up) / depth
        )
    }

    func visibility(of point: SIMD3<Double>) -> Double {
        dot(normalize(point), normalize(position - point))
    }
}
