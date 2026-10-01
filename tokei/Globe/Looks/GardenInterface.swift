import SwiftUI

extension InterfaceLook {
    static let garden: InterfaceLook = {
        let accent = SceneStyle.garden.accent
        let ink = Color(hex: 0x2E2A22)
        let secondaryInk = Color(hex: 0x6E6455)
        return InterfaceLook(
            colorScheme: .light,
            ink: ink,
            secondaryInk: secondaryInk,
            typography: InterfaceTypography(
                displayWeight: .light,
                titleWeight: .medium,
                captionCase: .uppercase,
                captionTracking: 2.0
            ),
            panel: .paper(fill: Color(hex: 0xEDE6D6), edge: Color(hex: 0xBFAE8A), shadow: .black.opacity(0.12)),
            panelCorner: 22,
            control: .paper(fill: Color(hex: 0xF4EFE4), edge: Color(hex: 0xBFAE8A), shadow: .black.opacity(0.08)),
            controlInk: ink,
            accentSurface: .solid(fill: accent, edge: nil),
            onAccent: .white,
            sheet: nil,
            chip: ChipLook(
                name: .init(size: 13, weight: .semibold),
                time: .init(size: 13, weight: .medium, monospacedDigits: true),
                detail: .init(size: 11, weight: .regular),
                corner: 9,
                surface: .solid(fill: Color(hex: 0xEDEAE3).opacity(0.95), edge: Color(hex: 0x9C9486).opacity(0.6)),
                selectedSurface: .solid(fill: accent, edge: nil),
                nameColor: ink,
                timeColor: secondaryInk,
                detailColor: secondaryInk,
                selectedInk: .white
            ),
            bead: BeadLook(
                body: Color(hex: 0x3F5A2C),
                shade: Color(hex: 0x223317),
                highlight: Color(hex: 0x8FA86A),
                outline: Color(hex: 0x0E1209).opacity(0.6),
                halo: accent.opacity(0.4)
            ),
            tape: TapeLook(
                tick: ink,
                label: secondaryInk,
                hourWidth: 1.4,
                quarterWidth: 0.9,
                needle: .bar
            ),
            swatch: SwatchLook(
                ocean: Color(hex: 0xE4E1DA),
                land: Color(hex: 0x3F5A2C),
                night: Color(hex: 0x1A2030).opacity(0.45),
                rim: Color(hex: 0x9C9486),
                finish: .raked
            )
        )
    }()
}
