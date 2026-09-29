import SwiftUI

struct ThemeSwatch: View {
    let look: SwatchLook
    let land: CGImage?

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height) * 0.92
            let rect = CGRect(x: (size.width - side) / 2, y: (size.height - side) / 2, width: side, height: side)
            let unit = side / 100
            let disk = Path(ellipseIn: rect)

            if look.finish == .paper {
                context.fill(Path(ellipseIn: rect.offsetBy(dx: 2.5 * unit, dy: 3.5 * unit)), with: .color(.black.opacity(0.14)))
            }
            context.fill(disk, with: .color(look.ocean))

            var surface = context
            surface.clip(to: disk)
            if let land {
                let image = surface.resolve(Image(decorative: land, scale: 1))
                if look.finish == .paper {
                    var shadow = surface
                    shadow.opacity = 0.2
                    shadow.addFilter(.colorMultiply(.black))
                    shadow.draw(image, in: rect.offsetBy(dx: 1.2 * unit, dy: 1.8 * unit))
                }
                var tinted = surface
                tinted.addFilter(.colorMultiply(look.land))
                tinted.draw(image, in: rect)
            }
            drawFinish(in: surface, rect: rect, unit: unit)

            let lit = CGRect(x: rect.midX - 22 * unit - 58 * unit, y: rect.midY - 14 * unit - 58 * unit, width: 116 * unit, height: 116 * unit)
            var night = Path(rect.insetBy(dx: -unit, dy: -unit))
            night.addEllipse(in: lit)
            surface.fill(night, with: .color(look.night), style: FillStyle(eoFill: true))

            drawRim(in: context, rect: rect, unit: unit)
        }
        .accessibilityHidden(true)
    }

    private func drawFinish(in context: GraphicsContext, rect: CGRect, unit: CGFloat) {
        switch look.finish {
        case .atmosphere, .paper:
            break
        case .clouds:
            for puff in Self.puffs {
                let center = CGPoint(x: rect.minX + puff.x * unit, y: rect.minY + puff.y * unit)
                context.fill(Path(ellipseIn: CGRect(x: center.x - puff.size * unit, y: center.y - puff.size * unit, width: 2 * puff.size * unit, height: 2 * puff.size * unit)), with: .color(.white))
            }
        case .gloss:
            let sheenRect = CGRect(x: rect.minX + 16 * unit, y: rect.minY + 10 * unit, width: 40 * unit, height: 24 * unit)
            let tilt = CGAffineTransform(translationX: sheenRect.midX, y: sheenRect.midY)
                .rotated(by: -.pi * 28 / 180)
                .translatedBy(x: -sheenRect.midX, y: -sheenRect.midY)
            context.fill(Path(ellipseIn: sheenRect).applying(tilt), with: .color(.white.opacity(0.3)))
            context.fill(Path(ellipseIn: CGRect(x: rect.minX + 24 * unit, y: rect.minY + 16 * unit, width: 11 * unit, height: 8 * unit)), with: .color(.white.opacity(0.9)))
        case .frost:
            for sparkle in Self.sparkles {
                let center = CGPoint(x: rect.minX + sparkle.x * unit, y: rect.minY + sparkle.y * unit)
                context.fill(star(at: center, radius: sparkle.size * unit), with: .color(.white.opacity(0.95)))
            }
        case .chrome:
            context.fill(Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 52 * unit)), with: .color(.white.opacity(0.14)))
            context.fill(Path(CGRect(x: rect.minX, y: rect.minY + 56 * unit, width: rect.width, height: 44 * unit)), with: .color(.black.opacity(0.3)))
            context.fill(Path(CGRect(x: rect.minX, y: rect.minY + 53 * unit, width: rect.width, height: 2 * unit)), with: .color(.white.opacity(0.3)))
            context.fill(Path(ellipseIn: CGRect(x: rect.minX + 22 * unit, y: rect.minY + 14 * unit, width: 16 * unit, height: 10 * unit)), with: .color(.white.opacity(0.9)))
        }
    }

    private func drawRim(in context: GraphicsContext, rect: CGRect, unit: CGFloat) {
        switch look.finish {
        case .atmosphere:
            context.stroke(Path(ellipseIn: rect.insetBy(dx: -2 * unit, dy: -2 * unit)), with: .color(look.rim.opacity(0.22)), lineWidth: 4 * unit)
            context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.6 * unit, dy: 0.6 * unit)), with: .color(look.rim.opacity(0.75)), lineWidth: 1.2 * unit)
        case .gloss:
            context.stroke(Path(ellipseIn: rect.insetBy(dx: 1.5 * unit, dy: 1.5 * unit)), with: .color(look.rim), lineWidth: 3 * unit)
        case .frost, .clouds:
            context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5 * unit, dy: 0.5 * unit)), with: .color(look.rim), lineWidth: unit)
        case .chrome:
            context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5 * unit, dy: 0.5 * unit)), with: .color(look.rim), lineWidth: unit)
            context.stroke(Path(ellipseIn: rect.insetBy(dx: -0.5 * unit, dy: -0.5 * unit)), with: .color(.black.opacity(0.8)), lineWidth: unit)
        case .paper:
            context.stroke(Path(ellipseIn: rect.insetBy(dx: 0.4 * unit, dy: 0.4 * unit)), with: .color(look.rim), lineWidth: 0.8 * unit)
        }
    }

    private func star(at center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        let waist = radius * 0.22
        path.move(to: CGPoint(x: center.x, y: center.y - radius))
        path.addLine(to: CGPoint(x: center.x + waist, y: center.y - waist))
        path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
        path.addLine(to: CGPoint(x: center.x + waist, y: center.y + waist))
        path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
        path.addLine(to: CGPoint(x: center.x - waist, y: center.y + waist))
        path.addLine(to: CGPoint(x: center.x - radius, y: center.y))
        path.addLine(to: CGPoint(x: center.x - waist, y: center.y - waist))
        path.closeSubpath()
        return path
    }

    private static let puffs: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (24, 36, 8),
        (34, 30, 10),
        (45, 35, 8),
        (33, 40, 7),
        (58, 66, 7),
        (67, 60, 9),
        (76, 66, 6.5),
    ]

    private static let sparkles: [(x: CGFloat, y: CGFloat, size: CGFloat)] = [
        (30, 26, 7),
        (62, 38, 4),
        (44, 62, 5),
        (22, 50, 3),
        (70, 22, 3.5),
    ]
}
