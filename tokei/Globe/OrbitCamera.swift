import CoreGraphics
import Foundation
import simd

struct OrbitCamera: Equatable {
    var yaw: Double
    var pitch: Double
    var distance: Double
    var centerY: Double

    static let minDistance = 1.8
    static let maxDistance = 6.5
    static let pitchLimit = 78 * Double.pi / 180

    var position: SIMD3<Double> {
        distance * SIMD3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw))
    }

    func clamped() -> OrbitCamera {
        var camera = self
        camera.pitch = min(max(pitch, -Self.pitchLimit), Self.pitchLimit)
        camera.distance = min(max(distance, Self.minDistance), Self.maxDistance)
        return camera
    }

    func rubberBanded() -> OrbitCamera {
        var camera = self
        camera.pitch = min(max(pitch, -Self.pitchLimit), Self.pitchLimit)
        if distance < Self.minDistance {
            camera.distance = Self.minDistance - Self.resistance(Self.minDistance - distance, limit: 0.35)
        }
        if distance > Self.maxDistance {
            camera.distance = Self.maxDistance + Self.resistance(distance - Self.maxDistance, limit: 1.2)
        }
        return camera
    }

    func facing(_ point: GeoPoint) -> OrbitCamera {
        var camera = self
        camera.yaw = point.longitude * .pi / 180
        camera.pitch = min(max(point.latitude * .pi / 180, -Self.pitchLimit), Self.pitchLimit) * 0.85
        return camera
    }

    func interpolated(to target: OrbitCamera, fraction: Double) -> OrbitCamera {
        let yawDelta = remainder(target.yaw - yaw, 2 * .pi)
        return OrbitCamera(
            yaw: yaw + yawDelta * fraction,
            pitch: pitch + (target.pitch - pitch) * fraction,
            distance: distance + (target.distance - distance) * fraction,
            centerY: centerY + (target.centerY - centerY) * fraction
        )
    }

    static func distance(fittingRadius radius: Double, focalLength: Double) -> Double {
        let ratio = focalLength / max(radius, 1)
        return min(max(sqrt(1 + ratio * ratio), minDistance), maxDistance)
    }

    private static func resistance(_ overshoot: Double, limit: Double) -> Double {
        limit * (1 - 1 / (overshoot / limit + 1))
    }
}

extension GeoPoint {
    var unitVector: SIMD3<Double> {
        let latitude = self.latitude * .pi / 180
        let longitude = self.longitude * .pi / 180
        return SIMD3(cos(latitude) * sin(longitude), sin(latitude), cos(latitude) * cos(longitude))
    }
}
