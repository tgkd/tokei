import SwiftUI

enum GardenSwatch {
    static func finish(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        let rake = Color(hex: 0xB9B4A8).opacity(0.35)
        var path = Path()
        var y = rect.minY + 3 * unit
        while y < rect.maxY - 3 * unit {
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: y), control: CGPoint(x: rect.midX, y: y + unit))
            y += 3 * unit
        }
        context.stroke(path, with: .color(rake), lineWidth: 0.5 * unit)
    }

    static func rim(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.4 * unit, dy: 0.4 * unit)), with: .color(look.rim), lineWidth: 0.8 * unit)
    }
}
