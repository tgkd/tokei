import SwiftUI

enum KnitSwatch {
    private static let wraps: [(rotation: Double, squash: Double, start: Double, end: Double)] = [
        (0.00, 0.32, 15, 165),
        (0.31, 0.50, 25, 155),
        (0.63, 0.74, 10, 170),
        (0.94, 0.94, 20, 160),
        (1.26, 0.66, 30, 150),
        (1.57, 0.44, 15, 165),
        (1.88, 0.82, 25, 155),
    ]

    static func finish(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2
        let yarn = Color(hex: 0xF4EEE2).opacity(0.45)
        for wrap in wraps {
            let transform = CGAffineTransform(translationX: center.x, y: center.y)
                .rotated(by: wrap.rotation)
                .scaledBy(x: 1, y: wrap.squash)
                .translatedBy(x: -center.x, y: -center.y)
            var path = Path()
            path.addArc(center: center, radius: radius, startAngle: .degrees(wrap.start), endAngle: .degrees(wrap.end), clockwise: false, transform: transform)
            context.stroke(path, with: .color(yarn), lineWidth: 0.8 * unit)
        }
    }

    static func rim(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        let ring = Path(ellipseIn: rect.insetBy(dx: 0.6 * unit, dy: 0.6 * unit))
        var glow = context
        glow.addFilter(.blur(radius: 1 * unit))
        glow.stroke(ring, with: .color(look.rim.opacity(0.6)), lineWidth: 1 * unit)
        context.stroke(ring, with: .color(look.rim), lineWidth: 0.8 * unit)
    }
}
