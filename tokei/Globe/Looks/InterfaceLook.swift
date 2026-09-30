import SwiftUI

struct InterfaceLook: Equatable {
    let colorScheme: ColorScheme
    let ink: Color
    let secondaryInk: Color
    let typography: InterfaceTypography
    let panel: SurfaceLook
    let panelCorner: CGFloat
    let control: SurfaceLook
    let controlInk: Color
    let accentSurface: SurfaceLook
    let onAccent: Color
    let sheet: Color?
    let chip: ChipLook
    let bead: BeadLook
    let tape: TapeLook
    let swatch: SwatchLook
}

extension SceneStyle {
    var interface: InterfaceLook {
        switch self {
        case .realistic: .realistic
        case .toy: .toy
        case .ice: .ice
        case .chrome: .chrome
        case .paper: .paper
        case .weather: .weather
        case .sakura: .sakura
        case .magma: .magma
        case .abyss: .abyss
        case .pixel: .pixel
        }
    }
}

extension EnvironmentValues {
    @Entry var sceneStyle: SceneStyle = .realistic
}

extension InterfaceLook {
    static let realistic: InterfaceLook = {
        let accent = SceneStyle.realistic.accent
        return InterfaceLook(
            colorScheme: .dark,
            ink: .white,
            secondaryInk: .white.opacity(0.62),
            typography: InterfaceTypography(
                displayWeight: .light,
                titleWeight: .semibold,
                captionWeight: .medium,
                captionCase: .uppercase,
                captionTracking: 0.9,
                symbolWeight: .medium
            ),
            panel: .glass(tint: nil, clear: false, edge: nil),
            panelCorner: 30,
            control: .glass(tint: nil, clear: false, edge: nil),
            controlInk: .white,
            accentSurface: .glass(tint: accent, clear: false, edge: nil),
            onAccent: legibleInk(on: accent),
            sheet: nil,
            chip: ChipLook(
                name: .init(size: 13, weight: .semibold),
                time: .init(size: 13, weight: .regular, monospacedDigits: true),
                detail: .init(size: 11, weight: .medium),
                corner: 12,
                surface: .solid(fill: .black.opacity(0.56), edge: .white.opacity(0.14)),
                nameColor: .white,
                timeColor: .white.opacity(0.72),
                detailColor: .white.opacity(0.6)
            ),
            bead: BeadLook(
                body: Color(hex: 0xF6F2E9),
                shade: Color(hex: 0x8C8A86),
                highlight: .white,
                outline: .black.opacity(0.62),
                halo: accent.opacity(0.35)
            ),
            tape: TapeLook(tick: .white, label: .white.opacity(0.55), needle: .capsule),
            swatch: SwatchLook(
                ocean: Color(hex: 0x123563),
                land: Color(hex: 0x7F8C5B),
                night: Color(hex: 0x02050B).opacity(0.82),
                rim: Color(hex: 0x86B8FF),
                finish: .atmosphere
            )
        )
    }()

    static let toy: InterfaceLook = {
        let accent = SceneStyle.toy.accent
        let backdrop = SceneStyle.toy.backdrop
        let plastic = backdrop.tone(saturation: 0.72, brightness: 0.44)
        let underside = backdrop.tone(saturation: 0.7, brightness: 0.13)
        let keycap = backdrop.tone(saturation: 0.3, brightness: 0.82)
        let deep = backdrop.tone(saturation: 0.8, brightness: 0.24)
        let muted = backdrop.tone(saturation: 0.45, brightness: 0.52)
        return InterfaceLook(
            colorScheme: .dark,
            ink: .white,
            secondaryInk: .white.opacity(0.68),
            typography: InterfaceTypography(
                design: .rounded,
                digitDesign: .rounded,
                displayWeight: .heavy,
                titleWeight: .bold,
                bodyWeight: .semibold,
                captionWeight: .semibold,
                symbolWeight: .heavy
            ),
            panel: .raised(fill: plastic, base: underside, depth: 5, edge: .white.opacity(0.08)),
            panelCorner: 32,
            control: .raised(fill: plastic, base: underside, depth: 3.5, edge: .white.opacity(0.08)),
            controlInk: .white,
            accentSurface: .raised(fill: accent, base: accent.mix(with: .black, by: 0.42), depth: 3, edge: nil),
            onAccent: deep,
            sheet: backdrop.tone(saturation: 0.72, brightness: 0.28),
            chip: ChipLook(
                name: .init(size: 13.5, weight: .bold, design: .rounded),
                time: .init(size: 13.5, weight: .semibold, design: .rounded, monospacedDigits: true),
                detail: .init(size: 11.5, weight: .semibold, design: .rounded),
                horizontalPadding: 11,
                verticalPadding: 5,
                corner: 100,
                surface: .raised(fill: Color(hex: 0xFFFDF8), base: keycap, depth: 2.5, edge: nil),
                selectedSurface: .raised(fill: accent, base: accent.mix(with: .black, by: 0.42), depth: 2.5, edge: nil),
                nameColor: deep,
                timeColor: muted,
                detailColor: muted,
                shiftedTimeColor: Color(hex: 0xE63E7A),
                selectedInk: deep
            ),
            bead: BeadLook(
                body: .white,
                shade: keycap,
                highlight: .white,
                outline: deep,
                outlineWidth: 1.4,
                halo: accent.opacity(0.45)
            ),
            tape: TapeLook(
                tick: .white,
                label: .white.opacity(0.62),
                labelWeight: .bold,
                labelDesign: .rounded,
                hourWidth: 2.5,
                quarterWidth: 2,
                needle: .chunky,
                needleOutline: underside
            ),
            swatch: SwatchLook(
                ocean: Color(hex: 0x1597C0),
                land: Color(hex: 0xFF5A9C),
                night: Color(hex: 0x06243B).opacity(0.6),
                rim: underside,
                finish: .gloss
            )
        )
    }()

    static let ice: InterfaceLook = {
        let accent = SceneStyle.ice.accent
        return InterfaceLook(
            colorScheme: .dark,
            ink: Color(hex: 0xF3F8FD),
            secondaryInk: Color(hex: 0x9FB4C9),
            typography: InterfaceTypography(
                digitWidth: .expanded,
                displayWeight: .light,
                titleWeight: .medium,
                bodyWeight: .light,
                captionWeight: .regular,
                captionCase: .uppercase,
                captionTracking: 1.4,
                symbolWeight: .light
            ),
            panel: .glass(tint: accent.opacity(0.06), clear: true, edge: .white.opacity(0.22)),
            panelCorner: 26,
            control: .glass(tint: nil, clear: true, edge: .white.opacity(0.26)),
            controlInk: Color(hex: 0xF3F8FD),
            accentSurface: .glass(tint: accent.opacity(0.85), clear: false, edge: nil),
            onAccent: legibleInk(on: accent),
            sheet: nil,
            chip: ChipLook(
                name: .init(size: 13, weight: .medium),
                time: .init(size: 13, weight: .light, monospacedDigits: true),
                detail: .init(size: 11, weight: .regular),
                corner: 7,
                surface: .solid(fill: Color(hex: 0x09101A).opacity(0.62), edge: .white.opacity(0.36)),
                nameColor: .white,
                timeColor: Color(hex: 0xC4D6E8),
                detailColor: Color(hex: 0x9FB4C9)
            ),
            bead: BeadLook(
                body: Color(hex: 0xEAF3FC),
                shade: Color(hex: 0x7C9CBC),
                highlight: .white,
                outline: Color(hex: 0x071019).opacity(0.75),
                halo: accent.opacity(0.4)
            ),
            tape: TapeLook(
                tick: Color(hex: 0xDCE8F4),
                label: Color(hex: 0x9FB4C9),
                labelWeight: .regular,
                hourWidth: 1,
                quarterWidth: 0.75,
                needle: .hairline
            ),
            swatch: SwatchLook(
                ocean: Color(hex: 0x17293B),
                land: Color(hex: 0xDCE5EE),
                night: Color(hex: 0x05080D).opacity(0.6),
                rim: .white.opacity(0.7),
                finish: .frost
            )
        )
    }()

    static let chrome: InterfaceLook = {
        let accent = SceneStyle.chrome.accent
        let backdrop = SceneStyle.chrome.backdrop
        let plate = backdrop.mix(with: .white, by: 0.1)
        return InterfaceLook(
            colorScheme: .dark,
            ink: Color(hex: 0xEDF0F4),
            secondaryInk: Color(hex: 0x959BA5),
            typography: InterfaceTypography(
                width: .condensed,
                digitDesign: .monospaced,
                displayWeight: .regular,
                titleWeight: .semibold,
                captionWeight: .semibold,
                captionCase: .uppercase,
                captionTracking: 1.6,
                symbolWeight: .semibold,
                engraved: true
            ),
            panel: .metal(fill: plate, highlight: .white.opacity(0.3), shade: .black.opacity(0.8), brushed: false),
            panelCorner: 22,
            control: .metal(fill: backdrop.mix(with: .white, by: 0.52), highlight: .white.opacity(0.55), shade: .black.opacity(0.85), brushed: true),
            controlInk: Color(hex: 0x16181C),
            accentSurface: .metal(fill: accent, highlight: .white, shade: .black.opacity(0.7), brushed: false),
            onAccent: legibleInk(on: accent, dark: Color(hex: 0x15171B)),
            sheet: backdrop.mix(with: .white, by: 0.05),
            chip: ChipLook(
                name: .init(size: 12.5, weight: .semibold, width: .condensed),
                time: .init(size: 12, weight: .medium, design: .monospaced),
                detail: .init(size: 10.5, weight: .medium, design: .monospaced),
                uppercasedName: true,
                horizontalPadding: 8,
                corner: 4,
                surface: .metal(fill: Color(hex: 0x1D1F24), highlight: .white.opacity(0.28), shade: .black.opacity(0.75), brushed: false),
                nameColor: Color(hex: 0xEEF1F5),
                timeColor: Color(hex: 0xA6ADB8),
                detailColor: Color(hex: 0x878D97)
            ),
            bead: BeadLook(
                body: Color(hex: 0xD8DCE3),
                shade: Color(hex: 0x50555E),
                highlight: .white,
                outline: Color(hex: 0x060709),
                halo: accent.opacity(0.4)
            ),
            tape: TapeLook(
                tick: Color(hex: 0xCACFD7),
                label: Color(hex: 0x8A909A),
                labelWeight: .medium,
                labelDesign: .monospaced,
                hourWidth: 1.5,
                quarterWidth: 1,
                squareCaps: true,
                needle: .bar,
                needleOutline: Color(hex: 0x060709)
            ),
            swatch: SwatchLook(
                ocean: Color(hex: 0xB9C1CC),
                land: Color(hex: 0xF3D69E),
                night: Color(hex: 0x1B1F2A).opacity(0.55),
                rim: .white.opacity(0.75),
                finish: .chrome
            )
        )
    }()

    static let paper: InterfaceLook = {
        let accent = SceneStyle.paper.accent
        let backdrop = SceneStyle.paper.backdrop
        let ink = Color(hex: 0x2F271F)
        let sheet = backdrop.mix(with: .white, by: 0.62)
        return InterfaceLook(
            colorScheme: .light,
            ink: ink,
            secondaryInk: Color(hex: 0x7A6B5B),
            typography: InterfaceTypography(
                design: .serif,
                digitDesign: .serif,
                displayWeight: .medium,
                titleWeight: .semibold,
                captionWeight: .regular,
                captionItalic: true,
                symbolWeight: .regular
            ),
            panel: .paper(fill: sheet, edge: ink.opacity(0.12), shadow: .black.opacity(0.1)),
            panelCorner: 24,
            control: .paper(fill: sheet, edge: ink.opacity(0.14), shadow: .black.opacity(0.12)),
            controlInk: ink,
            accentSurface: .raised(fill: accent, base: accent.mix(with: .black, by: 0.32), depth: 2, edge: nil),
            onAccent: legibleInk(on: accent, dark: ink),
            sheet: backdrop.mix(with: .white, by: 0.4),
            chip: ChipLook(
                name: .init(size: 13.5, weight: .semibold, design: .serif),
                time: .init(size: 13, weight: .regular, design: .serif, monospacedDigits: true),
                detail: .init(size: 11, weight: .regular, design: .serif, italic: true),
                verticalPadding: 4.5,
                corner: 3.5,
                surface: .raised(fill: Color(hex: 0xFFFCF6), base: .black.opacity(0.16), depth: 1.5, edge: ink.opacity(0.2)),
                nameColor: ink,
                timeColor: Color(hex: 0x7A6B5B),
                detailColor: Color(hex: 0x7A6B5B)
            ),
            bead: BeadLook(
                body: Color(hex: 0x3B3129),
                shade: .black.opacity(0.55),
                highlight: .white.opacity(0.9),
                outline: .black.opacity(0.25),
                outlineWidth: 0.75,
                shadow: .black.opacity(0.22)
            ),
            tape: TapeLook(
                tick: ink,
                label: Color(hex: 0x7A6B5B),
                labelWeight: .regular,
                labelDesign: .serif,
                hourWidth: 1.25,
                quarterWidth: 1,
                squareCaps: true,
                needle: .pin
            ),
            swatch: SwatchLook(
                ocean: Color(hex: 0x2A8291),
                land: Color(hex: 0xF39064),
                night: Color(hex: 0x45487D).opacity(0.3),
                rim: ink.opacity(0.35),
                finish: .paper
            )
        )
    }()

    static let weather: InterfaceLook = {
        let accent = SceneStyle.weather.accent
        let backdrop = SceneStyle.weather.backdrop
        let navy = Color(hex: 0x10213F)
        let mist = Color(hex: 0x6E83A3)
        return InterfaceLook(
            colorScheme: .dark,
            ink: .white,
            secondaryInk: Color(hex: 0xB7C7DC),
            typography: InterfaceTypography(
                design: .rounded,
                digitDesign: .rounded,
                displayWeight: .semibold,
                titleWeight: .semibold,
                bodyWeight: .medium,
                captionWeight: .medium,
                symbolWeight: .semibold
            ),
            panel: .glass(tint: Color(hex: 0x2B4F86).opacity(0.35), clear: false, edge: .white.opacity(0.16)),
            panelCorner: 30,
            control: .glass(tint: Color(hex: 0x2B4F86).opacity(0.3), clear: false, edge: .white.opacity(0.16)),
            controlInk: .white,
            accentSurface: .glass(tint: accent.opacity(0.9), clear: false, edge: nil),
            onAccent: navy,
            sheet: backdrop.mix(with: .white, by: 0.06),
            chip: ChipLook(
                name: .init(size: 13.5, weight: .semibold, design: .rounded),
                time: .init(size: 13.5, weight: .medium, design: .rounded, monospacedDigits: true),
                detail: .init(size: 11.5, weight: .medium, design: .rounded),
                horizontalPadding: 10,
                corner: 100,
                surface: .solid(fill: Color(hex: 0xFDFEFF).opacity(0.94), edge: Color(hex: 0xC9D6E6)),
                selectedSurface: .solid(fill: accent, edge: nil),
                nameColor: navy,
                timeColor: mist,
                detailColor: mist,
                shiftedTimeColor: Color(hex: 0x2F7BEA),
                selectedInk: navy
            ),
            bead: BeadLook(
                body: .white,
                shade: Color(hex: 0xB9C8DB),
                highlight: .white,
                outline: navy,
                outlineWidth: 1.2,
                halo: accent.opacity(0.45)
            ),
            tape: TapeLook(
                tick: .white,
                label: Color(hex: 0xB7C7DC),
                labelWeight: .semibold,
                labelDesign: .rounded,
                hourWidth: 2,
                quarterWidth: 1.5,
                needle: .capsule
            ),
            swatch: SwatchLook(
                ocean: Color(hex: 0x2A64A8),
                land: Color(hex: 0x9CBF79),
                night: Color(hex: 0x0B1A33).opacity(0.6),
                rim: .white.opacity(0.5),
                finish: .clouds
            )
        )
    }()

    static func legibleInk(on color: Color, dark: Color = Color(hex: 0x121212), light: Color = .white) -> Color {
        let resolved = color.resolve(in: EnvironmentValues())
        let luminance = 0.2126 * resolved.linearRed + 0.7152 * resolved.linearGreen + 0.0722 * resolved.linearBlue
        return luminance > 0.179 ? dark : light
    }
}

extension Color {
    func tone(saturation: Double, brightness: Double) -> Color {
        let resolved = resolve(in: EnvironmentValues())
        let red = Double(resolved.red)
        let green = Double(resolved.green)
        let blue = Double(resolved.blue)
        let top = max(red, green, blue)
        let delta = top - min(red, green, blue)
        guard delta > 0.0001 else {
            return Color(hue: 0, saturation: 0, brightness: brightness)
        }
        let sector: Double
        if top == red {
            sector = (green - blue) / delta
        } else if top == green {
            sector = (blue - red) / delta + 2
        } else {
            sector = (red - green) / delta + 4
        }
        let hue = (sector / 6).truncatingRemainder(dividingBy: 1)
        return Color(hue: hue < 0 ? hue + 1 : hue, saturation: saturation, brightness: brightness)
    }

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
