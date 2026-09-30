import SwiftUI

enum AbyssSwatch {
    private static let glow = Color(red: 0.55, green: 0.94, blue: 1)
    private static let shelf = Color(red: 0.18, green: 0.7, blue: 0.68)

    private static let specks: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (20, 58, 1.5),
        (27, 70, 1.1),
        (36, 79, 1.8),
        (47, 86, 1.2),
        (58, 80, 1.6),
        (31, 44, 1.0),
        (44, 66, 1.3),
        (63, 28, 1.1),
        (46, 20, 0.9),
    ]

    static func finish(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        var ring = context
        ring.addFilter(.blur(radius: 3 * unit))
        ring.stroke(Path(ellipseIn: rect.insetBy(dx: 7 * unit, dy: 7 * unit)), with: .color(shelf.opacity(0.45)), lineWidth: 5 * unit)
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 7 * unit, dy: 7 * unit)), with: .color(glow.opacity(0.28)), lineWidth: 0.6 * unit)
        for speck in specks {
            let center = CGPoint(x: rect.minX + speck.x * unit, y: rect.minY + speck.y * unit)
            let halo = speck.size * 2.6 * unit
            context.fill(Path(ellipseIn: CGRect(x: center.x - halo, y: center.y - halo, width: 2 * halo, height: 2 * halo)), with: .color(glow.opacity(0.16)))
            let core = speck.size * unit
            context.fill(Path(ellipseIn: CGRect(x: center.x - core, y: center.y - core, width: 2 * core, height: 2 * core)), with: .color(glow))
        }
    }

    static func rim(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        context.stroke(Path(ellipseIn: rect.insetBy(dx: -1.5 * unit, dy: -1.5 * unit)), with: .color(look.rim.opacity(0.25)), lineWidth: 3 * unit)
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5 * unit, dy: 0.5 * unit)), with: .color(look.rim), lineWidth: unit)
    }
}
