import SwiftUI

struct SurfaceButtonStyle<S: InsettableShape>: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let surface: SurfaceLook
    let shape: S

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(ThemedSurface(surface: surface, shape: shape, isInteractive: true, isPressed: configuration.isPressed))
            .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.24, bounce: 0.5), value: configuration.isPressed)
    }
}
