import Foundation

enum CameraMotion: Equatable {
    case inertia(start: Date, from: OrbitCamera, yawVelocity: Double, pitchVelocity: Double)
    case flight(start: Date, from: OrbitCamera, to: OrbitCamera, duration: Double, arc: Double)

    static let inertiaTime = 0.45
    private static let restingSpeed = 0.01

    func camera(at date: Date) -> OrbitCamera {
        switch self {
        case let .inertia(start, from, yawVelocity, pitchVelocity):
            let elapsed = max(0, date.timeIntervalSince(start))
            let travel = Self.inertiaTime * (1 - exp(-elapsed / Self.inertiaTime))
            var camera = from
            camera.yaw += yawVelocity * travel
            camera.pitch += pitchVelocity * travel
            return camera.clamped()
        case let .flight(start, from, to, duration, arc):
            let progress = min(max(date.timeIntervalSince(start) / duration, 0), 1)
            let eased = progress * progress * progress * (progress * (progress * 6 - 15) + 10)
            var camera = from.interpolated(to: to, fraction: eased)
            camera.distance += arc * sin(.pi * eased)
            return camera
        }
    }

    var endDate: Date {
        switch self {
        case let .inertia(start, _, yawVelocity, pitchVelocity):
            let speed = max(abs(yawVelocity), abs(pitchVelocity))
            guard speed > Self.restingSpeed else { return start }
            return start.addingTimeInterval(Self.inertiaTime * log(speed / Self.restingSpeed))
        case let .flight(start, _, _, duration, _):
            return start.addingTimeInterval(duration)
        }
    }
}
