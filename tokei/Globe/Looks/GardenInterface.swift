import SwiftUI

extension InterfaceLook {
    static let garden: InterfaceLook = {
        let accent = SceneStyle.garden.accent
        let ink = Color(hex: 0x22331E)
        let secondaryInk = Color(hex: 0x5C6E52)
        let mint = Color(hex: 0xE6F0D6)
        return InterfaceLook(
            colorScheme: .light,
            ink: ink,
            secondaryInk: secondaryInk,
            typography: InterfaceTypography(
                design: .rounded,
                digitDesign: .rounded,
                displayWeight: .regular,
                titleWeight: .semibold,
                bodyWeight: .regular,
                captionWeight: .medium,
                captionCase: .uppercase,
                captionTracking: 1.2,
                symbolWeight: .medium
            ),
            panel: .glass(tint: mint.opacity(0.45), clear: false, edge: .white.opacity(0.7)),
            panelCorner: 30,
            control: .glass(tint: mint.opacity(0.35), clear: false, edge: .white.opacity(0.7)),
            controlInk: ink,
            accentSurface: .glass(tint: accent.opacity(0.9), clear: false, edge: nil),
            onAccent: .white,
            sheet: Color(hex: 0xF6F9EF),
            chip: ChipLook(
                name: .init(size: 13, weight: .semibold, design: .rounded),
                time: .init(size: 13, weight: .medium, design: .rounded, monospacedDigits: true),
                detail: .init(size: 11, weight: .medium, design: .rounded),
                horizontalPadding: 10,
                verticalPadding: 5,
                corner: 100,
                surface: .solid(fill: Color(hex: 0xFDFEF8).opacity(0.95), edge: Color(hex: 0xB9D29A)),
                selectedSurface: .solid(fill: accent, edge: nil),
                nameColor: ink,
                timeColor: secondaryInk,
                detailColor: secondaryInk,
                shiftedTimeColor: accent,
                selectedInk: .white
            ),
            bead: BeadLook(
                body: Color(hex: 0xFFD447),
                shade: Color(hex: 0xE0A82A),
                highlight: .white,
                outline: ink.opacity(0.6),
                halo: accent.opacity(0.35)
            ),
            tape: TapeLook(
                tick: ink,
                label: secondaryInk,
                labelWeight: .medium,
                labelDesign: .rounded,
                hourWidth: 1.4,
                quarterWidth: 1,
                needle: .pin
            ),
            swatch: SwatchLook(
                ocean: Color(hex: 0x2A7BC0),
                land: Color(hex: 0x5DA53C),
                night: Color(hex: 0x1A2A40).opacity(0.45),
                rim: ink.opacity(0.25),
                finish: .flowers
            )
        )
    }()
}
