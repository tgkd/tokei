import CoreGraphics
import Foundation
import simd

struct GlobeFrame: Equatable {
    var camera: OrbitCamera
    var size: CGSize
    var sun: SIMD3<Double>
    var style: SceneStyle
    var effects = EffectSnapshot.none
    var weather: WeatherFrame?
    var petals: [PetalFlight] = []
    var marks = 0
    var surfaceRevision = 0

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

    var pickRadius: Double {
        style.hasClouds ? 1 + CloudShell.lift(inflate: effects.inflate) : 1
    }

    func surfacePoint(at location: CGPoint, radius: Double = 1) -> SIMD3<Double>? {
        let ray = normalize(forward * focalLength + right * Double(location.x - center.x) - up * Double(location.y - center.y))
        let along = dot(position, ray)
        let discriminant = along * along - dot(position, position) + radius * radius
        guard discriminant >= 0 else { return nil }
        let distance = -along - sqrt(discriminant)
        guard distance > 0 else { return nil }
        return normalize(position + ray * distance)
    }
}
