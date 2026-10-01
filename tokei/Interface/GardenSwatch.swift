import SwiftUI

enum GardenSwatch {
    private static let flowers: [(x: CGFloat, y: CGFloat, size: CGFloat, petal: UInt32, eye: UInt32)] = [
        (30, 36, 5.5, 0xFBF8F0, 0xF6C431),
        (46, 27, 4.5, 0xFFD447, 0x4A2C1A),
        (62, 58, 5, 0xF68FB2, 0xF6C431),
        (40, 61, 4, 0x6CB6F2, 0xF6C431),
        (73, 41, 4, 0xE8413A, 0x4A2C1A),
    ]

    static func finish(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        for flower in flowers {
            let center = CGPoint(x: rect.minX + flower.x * unit, y: rect.minY + flower.y * unit)
            let radius = flower.size * unit
            var petals = Path()
            for index in 0..<5 {
                let angle = Double(index) * 2 * .pi / 5 - .pi / 2
                let petal = CGPoint(x: center.x + cos(angle) * radius * 0.55, y: center.y + sin(angle) * radius * 0.55)
                petals.addEllipse(in: CGRect(x: petal.x - radius * 0.45, y: petal.y - radius * 0.45, width: radius * 0.9, height: radius * 0.9))
            }
            context.fill(petals, with: .color(Color(hex: flower.petal)))
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.28, y: center.y - radius * 0.28, width: radius * 0.56, height: radius * 0.56)), with: .color(Color(hex: flower.eye)))
        }
    }

    static func rim(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.4 * unit, dy: 0.4 * unit)), with: .color(look.rim), lineWidth: 0.8 * unit)
    }
}
