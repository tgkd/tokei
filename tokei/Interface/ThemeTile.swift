import SwiftUI

struct ThemeTile: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var swatchSize: CGFloat = 76

    let style: SceneStyle
    let land: CGImage?
    let isSelected: Bool

    var body: some View {
        let look = style.interface
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        VStack(spacing: 10) {
            ThemeSwatch(look: look.swatch, land: land)
                .frame(width: swatchSize, height: swatchSize)
            Text(style.displayName)
                .font(look.typography.title(.subheadline))
                .textCase(look.typography.captionCase)
                .tracking(look.typography.captionTracking)
                .foregroundStyle(look.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(width: swatchSize + 36)
        .background(style.backdrop, in: shape)
        .overlay {
            shape.strokeBorder(look.ink.opacity(0.14), lineWidth: 0.75)
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .strokeBorder(style.accent, lineWidth: 2.5)
                    .padding(-5)
            }
        }
        .overlay(alignment: .topTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(look.onAccent, style.accent)
                    .font(.system(size: 20, weight: .bold))
                    .offset(x: 8, y: -8)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }
        }
        .scaleEffect(isSelected || reduceMotion ? 1 : 0.93)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.5), value: isSelected)
    }
}
