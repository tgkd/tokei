import SwiftUI

struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var scale: CGFloat = 0.92

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed && reduceMotion ? 0.7 : 1)
            .animation(.spring(duration: 0.26, bounce: 0.5), value: configuration.isPressed)
    }
}
