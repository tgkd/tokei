import CoreGraphics
import Foundation

struct LabelRequest {
    let id: UUID
    let anchor: CGPoint
    let size: CGSize
    var previousCandidate: Int?
}

struct LabelPlacement: Equatable {
    let candidate: Int
    let frame: CGRect
}

enum LabelPlacer {
    static func place(
        _ requests: [LabelRequest],
        in bounds: CGRect,
        dotRadius: CGFloat,
        gap: CGFloat,
        spacing: CGFloat,
        entrySpacing: CGFloat,
        obstacles: [CGRect] = []
    ) -> [UUID: LabelPlacement] {
        var placed: [UUID: LabelPlacement] = [:]
        var occupied = obstacles
        let dots = requests.map { request in
            CGRect(
                x: request.anchor.x - dotRadius,
                y: request.anchor.y - dotRadius,
                width: dotRadius * 2,
                height: dotRadius * 2
            )
        }

        for (index, request) in requests.enumerated() {
            let margin = request.previousCandidate == nil ? entrySpacing : spacing
            let frames = candidates(for: request, dotRadius: dotRadius, gap: gap)
            var order = Array(frames.indices)
            if let previous = request.previousCandidate, frames.indices.contains(previous) {
                order.removeAll { $0 == previous }
                order.insert(previous, at: 0)
            }
            for candidate in order {
                let frame = frames[candidate]
                guard bounds.contains(frame) else { continue }
                let padded = frame.insetBy(dx: -margin, dy: -margin)
                let hitsLabel = occupied.contains { $0.intersects(padded) }
                let hitsDot = dots.enumerated().contains { $0.offset != index && $0.element.intersects(frame) }
                guard !hitsLabel, !hitsDot else { continue }
                placed[request.id] = LabelPlacement(candidate: candidate, frame: frame)
                occupied.append(frame)
                break
            }
        }
        return placed
    }

    private static func candidates(for request: LabelRequest, dotRadius: CGFloat, gap: CGFloat) -> [CGRect] {
        let width = request.size.width
        let height = request.size.height
        let x = request.anchor.x
        let y = request.anchor.y
        let offset = dotRadius + gap
        let middle = y - height / 2
        let lift = height * 0.62
        let origins = [
            CGPoint(x: x + offset, y: middle),
            CGPoint(x: x - offset - width, y: middle),
            CGPoint(x: x + offset, y: middle - lift),
            CGPoint(x: x + offset, y: middle + lift),
            CGPoint(x: x - offset - width, y: middle - lift),
            CGPoint(x: x - offset - width, y: middle + lift),
            CGPoint(x: x - width / 2, y: y - offset - height),
            CGPoint(x: x - width / 2, y: y + offset),
            CGPoint(x: x - width * 0.15, y: y - offset - height),
            CGPoint(x: x - width * 0.15, y: y + offset),
            CGPoint(x: x - width * 0.85, y: y - offset - height),
            CGPoint(x: x - width * 0.85, y: y + offset),
        ]
        return origins.map { CGRect(origin: $0, size: request.size) }
    }
}
