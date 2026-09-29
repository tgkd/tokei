import SwiftUI

struct ThemeTile: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var swatchSize: CGFloat = 40

    let style: SceneStyle
    let land: CGImage?
    let isSelected: Bool

    var body: some View {
        ThemeSwatch(look: style.interface.swatch, land: land)
            .frame(width: swatchSize, height: swatchSize)
            .padding(4)
            .overlay {
                Circle()
                    .strokeBorder(style.accent, lineWidth: 2)
                    .opacity(isSelected ? 1 : 0)
            }
            .contentShape(.circle)
            .scaleEffect(isSelected || reduceMotion ? 1 : 0.86)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.45, bounce: 0.5), value: isSelected)
    }
}
