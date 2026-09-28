import SwiftUI

struct ThemedSurface<S: InsettableShape>: ViewModifier {
    let surface: SurfaceLook
    let shape: S
    var outline: Color?
    var outlineWidth: CGFloat = 0.75
    var isInteractive = false
    var isPressed = false

    func body(content: Content) -> some View {
        switch surface {
        case let .glass(tint, clear, edge):
            content
                .glassEffect(glass(tint: tint, clear: clear), in: shape)
                .overlay {
                    stroke(outline ?? edge)
                }
        case let .solid(fill, edge):
            content
                .background {
                    shape.fill(fill)
                }
                .overlay {
                    stroke(outline ?? edge)
                }
                .scaleEffect(isPressed ? 0.95 : 1)
        case let .raised(fill, base, depth, edge):
            content
                .background {
                    shape.fill(fill)
                }
                .overlay {
                    stroke(outline ?? edge)
                }
                .offset(y: isPressed ? depth * 0.7 : 0)
                .background {
                    shape.fill(base)
                        .offset(y: depth)
                }
                .padding(.bottom, depth)
        case let .metal(fill, highlight, shade, brushed):
            content
                .background {
                    ZStack {
                        shape.fill(shade)
                            .offset(y: 1.25)
                        shape.fill(highlight)
                            .offset(y: -0.75)
                        if brushed {
                            shape.fill(AngularGradient(colors: Self.brushedStops(fill), center: .center, angle: .degrees(-20)))
                        } else {
                            shape.fill(LinearGradient(colors: Self.plateStops(fill), startPoint: .top, endPoint: .bottom))
                        }
                    }
                }
                .overlay {
                    stroke(outline)
                }
                .scaleEffect(isPressed ? 0.95 : 1)
        case let .paper(fill, edge, shadow):
            content
                .background {
                    shape.fill(fill)
                        .shadow(color: shadow, radius: isPressed ? 1.5 : 7, y: isPressed ? 1 : 3.5)
                }
                .overlay {
                    stroke(outline ?? edge)
                }
                .scaleEffect(isPressed ? 0.96 : 1)
        }
    }

    @ViewBuilder
    private func stroke(_ color: Color?) -> some View {
        if let color {
            shape.strokeBorder(color, lineWidth: outline == nil ? 0.75 : outlineWidth)
        }
    }

    private static func plateStops(_ fill: Color) -> [Color] {
        [fill.mix(with: .white, by: 0.14), fill, fill.mix(with: .black, by: 0.22)]
    }

    private static func brushedStops(_ fill: Color) -> [Color] {
        let light = fill.mix(with: .white, by: 0.42)
        let dark = fill.mix(with: .black, by: 0.18)
        return [light, dark, fill, light, dark, fill, light]
    }

    private func glass(tint: Color?, clear: Bool) -> Glass {
        var glass: Glass = clear ? .clear : .regular
        if let tint {
            glass = glass.tint(tint)
        }
        if isInteractive {
            glass = glass.interactive()
        }
        return glass
    }
}

extension View {
    func surface<S: InsettableShape>(_ surface: SurfaceLook, in shape: S, outline: Color? = nil, outlineWidth: CGFloat = 0.75) -> some View {
        modifier(ThemedSurface(surface: surface, shape: shape, outline: outline, outlineWidth: outlineWidth))
    }
}
