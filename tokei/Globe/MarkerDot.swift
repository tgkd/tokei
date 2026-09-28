import SwiftUI

struct MarkerDot: View {
    @Environment(\.sceneStyle) private var style
    @Environment(\.sceneAccent) private var accent

    let isSelected: Bool

    var body: some View {
        let bead = style.interface.bead
        let diameter = ChipMetrics.dotRadius * 2
        Canvas { context, size in
            let rect = CGRect(x: (size.width - diameter) / 2, y: (size.height - diameter) / 2, width: diameter, height: diameter)
            let ball = Path(ellipseIn: rect)
            if isSelected, let halo = bead.halo {
                context.stroke(Path(ellipseIn: rect.insetBy(dx: -3.5, dy: -3.5)), with: .color(halo), lineWidth: 2)
            }
            if let shadow = bead.shadow {
                context.fill(Path(ellipseIn: rect.offsetBy(dx: 0.9, dy: 1.5)), with: .color(shadow))
            }
            context.fill(ball, with: .color(isSelected ? accent : bead.body))
            var shading = context
            shading.clip(to: ball)
            var crescent = Path(rect.insetBy(dx: -2, dy: -2))
            crescent.addEllipse(in: rect.offsetBy(dx: -diameter * 0.16, dy: -diameter * 0.2))
            shading.fill(crescent, with: .color(isSelected ? .black.opacity(0.24) : bead.shade), style: FillStyle(eoFill: true))
            let spark = CGRect(x: rect.minX + diameter * 0.2, y: rect.minY + diameter * 0.15, width: diameter * 0.34, height: diameter * 0.27)
            shading.fill(Path(ellipseIn: spark), with: .color(bead.highlight))
            let inset = bead.outlineWidth / 2
            context.stroke(Path(ellipseIn: rect.insetBy(dx: inset, dy: inset)), with: .color(bead.outline), lineWidth: bead.outlineWidth)
        }
        .frame(width: diameter + 10, height: diameter + 10)
    }
}
