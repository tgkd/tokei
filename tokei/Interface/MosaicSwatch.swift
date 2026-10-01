import SwiftUI

enum MosaicSwatch {
    private static let grout = Color(hex: 0xD8D1C3)

    private static let shards: [(x: CGFloat, y: CGFloat, size: CGFloat, turn: CGFloat)] = [
        (18, 30, 7, 0.2), (30, 20, 6, 0.9), (44, 14, 7, 0.4), (60, 16, 6, 1.3), (74, 24, 7, 0.7),
        (84, 38, 6, 1.1), (14, 46, 6, 0.5), (28, 38, 7, 1.4), (42, 30, 6, 0.1), (58, 32, 7, 0.8),
        (72, 42, 6, 0.3), (86, 54, 6, 1.2), (20, 60, 7, 0.9), (34, 54, 6, 0.2), (48, 46, 7, 1.0),
        (62, 50, 6, 0.6), (76, 60, 7, 1.5), (26, 74, 6, 0.4), (40, 68, 7, 1.1), (54, 62, 6, 0.3),
        (68, 72, 7, 0.9), (82, 70, 6, 0.1), (36, 84, 6, 1.3), (50, 78, 7, 0.7), (64, 86, 6, 0.2),
        (16, 18, 5, 1.0), (52, 92, 5, 0.6), (90, 42, 5, 1.4), (10, 58, 5, 0.3), (78, 84, 5, 0.8),
    ]

    static func finish(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        for (index, shard) in shards.enumerated() {
            let path = quad(shard, rect: rect, unit: unit, index: index)
            let fill = index % 2 == 0 ? Color.white.opacity(0.35) : look.ocean.mix(with: .white, by: 0.35).opacity(0.35)
            context.fill(path, with: .color(fill))
            context.stroke(path, with: .color(grout.opacity(0.6)), lineWidth: 0.5 * unit)
        }
    }

    static func rim(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5 * unit, dy: 0.5 * unit)), with: .color(look.rim), lineWidth: unit)
    }

    private static func quad(_ shard: (x: CGFloat, y: CGFloat, size: CGFloat, turn: CGFloat), rect: CGRect, unit: CGFloat, index: Int) -> Path {
        let center = CGPoint(x: rect.minX + shard.x * unit, y: rect.minY + shard.y * unit)
        let stretches: [CGFloat] = [1.0, 0.8, 1.1, 0.75]
        var path = Path()
        for corner in 0..<4 {
            let angle = shard.turn + CGFloat(corner) * .pi / 2 + CGFloat((index + corner) % 3) * 0.12
            let radius = shard.size * 0.5 * unit * stretches[(index + corner) % 4]
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if corner == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
