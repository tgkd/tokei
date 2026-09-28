import CoreGraphics
import Foundation

@MainActor
final class GlobeTouch {
    enum Phase {
        case idle
        case pending
        case rotating
        case holding
        case dragging
    }

    enum Step: Equatable {
        case beginDrag
        case drag
        case endDrag
        case release(moved: Bool)
    }

    static let holdDuration = 0.25
    static let holdTolerance = 8.0
    static let engageDistance = 3.0
    static let releaseTolerance = 10.0

    private(set) var phase = Phase.idle
    private var origin = CGPoint.zero
    private var anchor = CGPoint.zero
    private var start = Date.distantPast
    private var wandered = 0.0

    func begin(at location: CGPoint, holds: Bool, now: Date = Date()) {
        origin = location
        anchor = location
        start = now
        wandered = 0
        phase = holds ? .pending : .rotating
    }

    func move(to location: CGPoint, now: Date = Date()) -> Step? {
        armIfHeld(at: now)
        switch phase {
        case .pending:
            wandered = max(wandered, distance(from: origin, to: location))
            anchor = location
            if wandered >= Self.holdTolerance {
                phase = .rotating
            }
            return nil
        case .holding:
            guard distance(from: anchor, to: location) >= Self.engageDistance else { return nil }
            wandered = max(wandered, distance(from: origin, to: location))
            phase = .dragging
            return .beginDrag
        case .dragging:
            return .drag
        case .idle, .rotating:
            wandered = max(wandered, distance(from: origin, to: location))
            return nil
        }
    }

    func crowd() -> Step? {
        guard phase != .idle else { return nil }
        let wasDragging = phase == .dragging
        wandered = .infinity
        phase = .rotating
        return wasDragging ? .endDrag : nil
    }

    func end(at location: CGPoint) -> Step {
        let wasDragging = phase == .dragging
        wandered = max(wandered, distance(from: origin, to: location))
        phase = .idle
        if wasDragging {
            return .endDrag
        }
        return .release(moved: wandered > Self.releaseTolerance)
    }

    func allowsRotation(now: Date = Date()) -> Bool {
        armIfHeld(at: now)
        switch phase {
        case .idle, .rotating:
            return true
        case .pending, .holding, .dragging:
            return false
        }
    }

    private func armIfHeld(at now: Date) {
        if phase == .pending && now.timeIntervalSince(start) >= Self.holdDuration {
            phase = .holding
        }
    }

    private func distance(from lhs: CGPoint, to rhs: CGPoint) -> Double {
        Double(hypot(rhs.x - lhs.x, rhs.y - lhs.y))
    }
}
