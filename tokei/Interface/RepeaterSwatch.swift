import SwiftUI

enum RepeaterSwatch {
    private static let enamel = Color(hex: 0x3A6EA5)

    static func finish(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width * 0.5
        context.fill(Path(ellipseIn: rect), with: .color(enamel.opacity(0.16)))
        var wave = Path()
        for step in 1...6 {
            let r = radius * (0.24 + 0.11 * CGFloat(step))
            wave.addArc(center: center, radius: r, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
        }
        context.stroke(wave, with: .color(Color(hex: 0xC7E0F5).opacity(0.55)), lineWidth: 0.8 * unit)
        context.fill(
            Path(ellipseIn: CGRect(x: rect.minX + 15 * unit, y: rect.minY + 11 * unit, width: 42 * unit, height: 24 * unit)),
            with: .color(.white.opacity(0.22))
        )
    }

    static func rim(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5 * unit, dy: 0.5 * unit)), with: .color(look.rim), lineWidth: 1.4 * unit)
        context.stroke(Path(ellipseIn: rect.insetBy(dx: -1.5 * unit, dy: -1.5 * unit)), with: .color(look.rim.opacity(0.45)), lineWidth: 3 * unit)
    }
}
