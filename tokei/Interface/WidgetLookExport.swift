import SwiftUI

extension WidgetLook {
    init(style: SceneStyle) {
        let interface = style.interface
        let typography = interface.typography
        let chip = interface.chip
        let backdrop = style.backdrop.resolved
        let label = Surface(chip.surface, over: style.backdrop, ink: interface.ink)
        let control = Surface(interface.control, over: style.backdrop, ink: interface.ink)
        let accents = [style.accent, chip.shiftedTimeColor].compactMap { $0 }
        self.init(
            typography: Typography(
                title: Face(design: Design(typography.design), width: typography.width.value, weight: Weight(typography.titleWeight)),
                digits: Face(design: Design(typography.digitDesign), width: typography.digitWidth.value, weight: Weight(typography.displayWeight)),
                caption: Face(
                    design: Design(typography.design),
                    width: typography.width.value,
                    weight: Weight(typography.captionWeight),
                    italic: typography.captionItalic
                ),
                uppercasedCaptions: typography.captionCase == .uppercase,
                captionTracking: typography.captionTracking,
                symbolWeight: Weight(typography.symbolWeight),
                labelName: Face(chip.name),
                labelTime: Face(chip.time),
                uppercasedLabelNames: chip.uppercasedName
            ),
            background: backdrop,
            ink: interface.ink.resolved,
            secondaryInk: interface.secondaryInk.resolved,
            accent: Self.legible(accents, on: backdrop, toward: interface.ink),
            label: Label(
                surface: label,
                corner: ChipMetrics.corner(chip, isExpanded: true),
                nameColor: chip.nameColor.resolved,
                timeColor: chip.timeColor.resolved,
                shiftedTimeColor: Self.legible([chip.shiftedTimeColor ?? style.accent], on: label.fill.composited(over: backdrop), toward: chip.nameColor)
            ),
            dot: Dot(fill: interface.bead.body.resolved, outline: interface.bead.outline.resolved, outlineWidth: interface.bead.outlineWidth),
            control: control,
            controlInk: interface.controlInk.resolved,
            controlAccent: Self.legible(accents, on: control.fill.composited(over: backdrop), toward: interface.controlInk),
            map: Self.map(interface.swatch, backdrop: style.backdrop, pixelSize: style.mesh?.pixelSize)
        )
    }

    private static func legible(_ candidates: [Color], on background: Color.Resolved, toward ink: Color) -> Color.Resolved {
        if let match = candidates.map(\.resolved).first(where: { contrast($0, on: background) >= 3 }) {
            return match
        }
        let preferred = candidates.first ?? ink
        for amount in [0.25, 0.5, 0.75] {
            let mixed = preferred.mix(with: ink, by: amount).resolved
            if contrast(mixed, on: background) >= 3 {
                return mixed
            }
        }
        return ink.resolved
    }

    private static func contrast(_ color: Color.Resolved, on background: Color.Resolved) -> Float {
        let top = color.composited(over: background).luminance
        let bottom = background.luminance
        return (max(top, bottom) + 0.05) / (min(top, bottom) + 0.05)
    }

    private static func map(_ swatch: SwatchLook, backdrop: Color, pixelSize: Double?) -> Map {
        if swatch.finish == .atmosphere {
            return .photo
        }
        let night = swatch.night.resolved.opacity > 0 ? swatch.night : backdrop.opacity(0.78)
        return .flat(
            ocean: swatch.ocean.resolved,
            land: swatch.land.resolved,
            coast: swatch.rim.resolved,
            night: night.resolved,
            pixelSize: pixelSize.map { CGFloat($0) }
        )
    }
}

private extension Color.Resolved {
    var luminance: Float {
        0.2126 * linearRed + 0.7152 * linearGreen + 0.0722 * linearBlue
    }

    func composited(over background: Color.Resolved) -> Color.Resolved {
        Color.Resolved(
            colorSpace: .sRGBLinear,
            red: linearRed * opacity + background.linearRed * (1 - opacity),
            green: linearGreen * opacity + background.linearGreen * (1 - opacity),
            blue: linearBlue * opacity + background.linearBlue * (1 - opacity)
        )
    }
}

private extension WidgetLook.Face {
    init(_ face: ChipLook.Face) {
        self.init(design: WidgetLook.Design(face.design), width: face.width.value, weight: WidgetLook.Weight(face.weight), italic: face.italic)
    }
}

private extension WidgetLook.Surface {
    init(_ surface: SurfaceLook, over backdrop: Color, ink: Color) {
        switch surface {
        case let .glass(tint, _, edge):
            self.init(fill: Self.frosted(backdrop, tint: tint ?? ink.opacity(0.12)), edge: (edge ?? ink.opacity(0.14)).resolved)
        case let .solid(fill, edge):
            self.init(fill: fill.resolved, edge: edge?.resolved)
        case let .raised(fill, base, depth, edge):
            self.init(fill: fill.resolved, edge: edge?.resolved, base: base.resolved, offset: CGSize(width: 0, height: depth))
        case let .metal(fill, highlight, shade, _):
            self.init(fill: fill.resolved, edge: highlight.opacity(0.5).resolved, base: shade.resolved, offset: CGSize(width: 0, height: 1.25))
        case let .paper(fill, edge, shadow):
            self.init(fill: fill.resolved, edge: edge.resolved, base: shadow.resolved, offset: CGSize(width: 0, height: 1.5))
        case let .pixel(fill, edge, shadow, depth):
            self.init(fill: fill.resolved, edge: edge.resolved, edgeWidth: 2, base: shadow.resolved, offset: CGSize(width: depth, height: depth))
        }
    }

    static func frosted(_ backdrop: Color, tint: Color) -> Color.Resolved {
        let base = backdrop.resolved
        let layer = tint.resolved
        let cover = layer.opacity
        return Color.Resolved(
            red: base.red + (layer.red - base.red) * cover,
            green: base.green + (layer.green - base.green) * cover,
            blue: base.blue + (layer.blue - base.blue) * cover,
            opacity: 0.9
        )
    }
}

private extension WidgetLook.Weight {
    init(_ weight: Font.Weight) {
        switch weight {
        case .ultraLight: self = .ultraLight
        case .thin: self = .thin
        case .light: self = .light
        case .medium: self = .medium
        case .semibold: self = .semibold
        case .bold: self = .bold
        case .heavy: self = .heavy
        case .black: self = .black
        default: self = .regular
        }
    }
}

private extension WidgetLook.Design {
    init(_ design: Font.Design) {
        switch design {
        case .serif: self = .serif
        case .rounded: self = .rounded
        case .monospaced: self = .monospaced
        default: self = .standard
        }
    }
}
