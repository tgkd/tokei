import Foundation

struct ShiftGlide: Equatable {
    let start: Date
    let origin: Double
    let velocity: Double
    let target: Double

    private static let stiffness = 10.0
    static let duration = 1.1

    func value(at date: Date) -> Double {
        let elapsed = min(max(date.timeIntervalSince(start), 0), Self.duration)
        let offset = origin - target
        let omega = Self.stiffness
        let value = target + (offset + (velocity + omega * offset) * elapsed) * exp(-omega * elapsed)
        return elapsed >= Self.duration ? target : value
    }

    var endDate: Date {
        start.addingTimeInterval(Self.duration)
    }
}
