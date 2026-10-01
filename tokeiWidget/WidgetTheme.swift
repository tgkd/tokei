import SwiftUI
import WidgetKit

extension EnvironmentValues {
    @Entry var widgetLook: WidgetLook = .standard
}

extension WidgetLook {
    var faintInk: Color {
        Color(secondaryInk).opacity(0.75)
    }

    var rule: Color {
        Color(ink).opacity(0.1)
    }
}

struct ThemedContainer: ViewModifier {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let look: WidgetLook

    func body(content: Content) -> some View {
        let look = renderingMode == .fullColor ? look : look.neutral
        content
            .environment(\.widgetLook, look)
            .containerBackground(look.background, for: .widget)
    }
}

struct WidgetSurface<S: InsettableShape>: ViewModifier {
    let surface: WidgetLook.Surface
    let shape: S

    func body(content: Content) -> some View {
        content
            .background {
                shape.fill(surface.fill)
            }
            .overlay {
                if let edge = surface.edge {
                    shape.strokeBorder(edge, lineWidth: surface.edgeWidth)
                }
            }
            .background {
                if let base = surface.base {
                    shape.fill(base)
                        .offset(surface.offset)
                }
            }
    }
}

extension View {
    func themedContainer(_ look: WidgetLook) -> some View {
        modifier(ThemedContainer(look: look))
    }

    func widgetSurface<S: InsettableShape>(_ surface: WidgetLook.Surface, in shape: S) -> some View {
        modifier(WidgetSurface(surface: surface, shape: shape))
    }

    func caption(_ look: WidgetLook, size: CGFloat) -> some View {
        font(look.typography.caption.font(size: size))
            .tracking(look.typography.captionTracking)
    }
}
