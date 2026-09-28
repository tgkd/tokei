import CoreGraphics
import Foundation

struct SurfaceStroke {
    static let grainInterval = 0.035
    static let fullSpeed = 1400.0

    var trail: SnowTrail
    private var location: CGPoint
    private var time: Date
    private var travel = 0.0
    private var speed = 0.0
    private var lastGrain = Date.distantPast

    init(trail: SnowTrail, location: CGPoint, time: Date) {
        self.trail = trail
        self.location = location
        self.time = time
    }

    mutating func advance(to location: CGPoint, at time: Date, onSurface: Bool, spacing: Double) -> Double? {
        let step = Double(hypot(location.x - self.location.x, location.y - self.location.y))
        let elapsed = max(time.timeIntervalSince(self.time), 1.0 / 240)
        self.location = location
        self.time = time
        speed += (step / elapsed - speed) * 0.35
        guard onSurface else { return nil }
        travel = min(travel + step, spacing * 2)
        guard travel >= spacing, time.timeIntervalSince(lastGrain) >= Self.grainInterval else { return nil }
        travel -= spacing
        lastGrain = time
        return min(speed / Self.fullSpeed, 1)
    }
}
