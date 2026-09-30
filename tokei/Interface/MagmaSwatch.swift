import SwiftUI

enum MagmaSwatch {
    private static let molten = Color(hex: 0xFFB229)

    private static let cracks: [[CGPoint]] = [
        [CGPoint(x: 14, y: 40), CGPoint(x: 27, y: 36), CGPoint(x: 38, y: 42), CGPoint(x: 51, y: 36), CGPoint(x: 64, y: 43), CGPoint(x: 78, y: 39)],
        [CGPoint(x: 38, y: 42), CGPoint(x: 42, y: 54), CGPoint(x: 36, y: 66), CGPoint(x: 42, y: 80)],
        [CGPoint(x: 51, y: 36), CGPoint(x: 55, y: 24), CGPoint(x: 67, y: 17)],
        [CGPoint(x: 64, y: 43), CGPoint(x: 75, y: 52), CGPoint(x: 82, y: 64)],
        [CGPoint(x: 42, y: 54), CGPoint(x: 56, y: 58), CGPoint(x: 63, y: 71), CGPoint(x: 60, y: 84)],
        [CGPoint(x: 27, y: 36), CGPoint(x: 24, y: 23), CGPoint(x: 33, y: 14)],
        [CGPoint(x: 56, y: 58), CGPoint(x: 75, y: 52)],
    ]

    static func finish(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        var path = Path()
        for crack in cracks {
            guard let first = crack.first else { continue }
            path.move(to: point(first, rect: rect, unit: unit))
            for next in crack.dropFirst() {
                path.addLine(to: point(next, rect: rect, unit: unit))
            }
        }
        var glow = context
        glow.addFilter(.blur(radius: 1.8 * unit))
        glow.stroke(path, with: .color(look.rim.opacity(0.95)), style: StrokeStyle(lineWidth: 3.2 * unit, lineCap: .round, lineJoin: .round))
        context.stroke(path, with: .color(look.rim), style: StrokeStyle(lineWidth: 1.6 * unit, lineCap: .round, lineJoin: .round))
        context.stroke(path, with: .color(molten), style: StrokeStyle(lineWidth: 0.7 * unit, lineCap: .round, lineJoin: .round))
    }

    static func rim(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        let ring = Path(ellipseIn: rect.insetBy(dx: 0.6 * unit, dy: 0.6 * unit))
        var glow = context
        glow.addFilter(.blur(radius: 1.6 * unit))
        glow.stroke(ring, with: .color(look.rim.opacity(0.75)), lineWidth: 2.4 * unit)
        context.stroke(ring, with: .color(look.rim.opacity(0.9)), lineWidth: 1.1 * unit)
    }

    private static func point(_ point: CGPoint, rect: CGRect, unit: CGFloat) -> CGPoint {
        CGPoint(x: rect.minX + point.x * unit, y: rect.minY + point.y * unit)
    }
}
