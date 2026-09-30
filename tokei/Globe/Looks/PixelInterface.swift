import SwiftUI

extension InterfaceLook {
    static let pixel: InterfaceLook = {
        let accent = SceneStyle.pixel.accent
        let void = Color(hex: 0x1A1C2C)
        let navy = Color(hex: 0x29366F)
        let charcoal = Color(hex: 0x333C57)
        let silver = Color(hex: 0x94B0C2)
        let white = Color(hex: 0xF4F4F4)
        let cyan = Color(hex: 0x73EFF7)
        let shadow = Color(hex: 0x0B0C14)
        return InterfaceLook(
            colorScheme: .dark,
            ink: white,
            secondaryInk: silver,
            typography: InterfaceTypography(
                design: .monospaced,
                digitDesign: .monospaced,
                displayWeight: .heavy,
                titleWeight: .heavy,
                bodyWeight: .bold,
                captionWeight: .bold,
                captionCase: .uppercase,
                captionTracking: 1,
                symbolWeight: .heavy
            ),
            panel: .pixel(fill: navy, edge: white, shadow: shadow, depth: 4),
            panelCorner: 0,
            control: .pixel(fill: charcoal, edge: silver, shadow: shadow, depth: 3),
            controlInk: white,
            accentSurface: .pixel(fill: accent, edge: white, shadow: shadow, depth: 3),
            onAccent: void,
            sheet: void,
            chip: ChipLook(
                name: .init(size: 12, weight: .heavy, design: .monospaced),
                time: .init(size: 12, weight: .bold, design: .monospaced, monospacedDigits: true),
                detail: .init(size: 10.5, weight: .bold, design: .monospaced),
                uppercasedName: true,
                horizontalPadding: 7,
                verticalPadding: 4,
                corner: 0,
                surface: .pixel(fill: void, edge: white, shadow: shadow, depth: 2),
                selectedSurface: .pixel(fill: accent, edge: white, shadow: shadow, depth: 2),
                nameColor: white,
                timeColor: cyan,
                detailColor: silver,
                shiftedTimeColor: accent,
                selectedInk: void
            ),
            bead: BeadLook(
                body: white,
                shade: silver,
                highlight: .white,
                outline: void,
                outlineWidth: 1.5,
                halo: accent.opacity(0.55)
            ),
            tape: TapeLook(
                tick: white,
                label: silver,
                labelWeight: .bold,
                labelDesign: .monospaced,
                hourWidth: 2,
                quarterWidth: 2,
                squareCaps: true,
                needle: .pixel,
                needleOutline: shadow
            ),
            swatch: SwatchLook(
                ocean: Color(hex: 0x3B5DC9),
                land: Color(hex: 0x38B764),
                night: .clear,
                rim: void,
                finish: .pixel
            )
        )
    }()
}
