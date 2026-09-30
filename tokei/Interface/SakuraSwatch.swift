import SwiftUI

enum SakuraSwatch {
    private static let blossoms: [(x: CGFloat, y: CGFloat, size: CGFloat, turn: Double)] = [
        (30, 34, 7, 0.2),
        (47, 26, 5, 1.1),
        (62, 58, 6.5, 0.6),
        (40, 60, 4.5, 1.7),
        (74, 40, 4, 0.9),
    ]

    static func finish(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        for blossom in blossoms {
            let center = CGPoint(x: rect.minX + blossom.x * unit, y: rect.minY + blossom.y * unit)
            let radius = blossom.size * unit
            context.fill(flower(at: center, radius: radius, turn: blossom.turn), with: .color(Color(hex: 0xFFF3F6)))
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.22, y: center.y - radius * 0.22, width: radius * 0.44, height: radius * 0.44)), with: .color(Color(hex: 0xD6517A)))
        }
    }

    static func rim(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        context.stroke(Path(ellipseIn: rect.insetBy(dx: -1.5 * unit, dy: -1.5 * unit)), with: .color(Color(hex: 0xF6C9D4).opacity(0.6)), lineWidth: 3 * unit)
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5 * unit, dy: 0.5 * unit)), with: .color(look.rim), lineWidth: unit)
    }

    private static func flower(at center: CGPoint, radius: CGFloat, turn: Double) -> Path {
        var path = Path()
        for index in 0..<5 {
            let angle = turn + Double(index) * 2 * .pi / 5
            let side = radius * 0.42
            let left = CGPoint(x: center.x + cos(angle - 0.55) * side, y: center.y + sin(angle - 0.55) * side)
            let right = CGPoint(x: center.x + cos(angle + 0.55) * side, y: center.y + sin(angle + 0.55) * side)
            let notch = CGPoint(x: center.x + cos(angle) * radius * 0.82, y: center.y + sin(angle) * radius * 0.82)
            let leftTip = CGPoint(x: center.x + cos(angle - 0.2) * radius * 1.02, y: center.y + sin(angle - 0.2) * radius * 1.02)
            let rightTip = CGPoint(x: center.x + cos(angle + 0.2) * radius * 1.02, y: center.y + sin(angle + 0.2) * radius * 1.02)
            path.move(to: center)
            path.addQuadCurve(to: leftTip, control: left)
            path.addLine(to: notch)
            path.addLine(to: rightTip)
            path.addQuadCurve(to: center, control: right)
            path.closeSubpath()
        }
        return path
    }
}
