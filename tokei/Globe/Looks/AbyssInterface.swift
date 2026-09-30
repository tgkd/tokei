import SwiftUI

extension InterfaceLook {
    static let abyss: InterfaceLook = {
        let accent = SceneStyle.abyss.accent
        let backdrop = SceneStyle.abyss.backdrop
        let ink = Color(hex: 0xE6FBFF)
        let mist = Color(hex: 0x8FB9C4)
        let deep = Color(hex: 0x03202E)
        let teal = Color(hex: 0x0E5F6E)
        let glow = Color(hex: 0x8BEFFF)
        return InterfaceLook(
            colorScheme: .dark,
            ink: ink,
            secondaryInk: mist,
            typography: InterfaceTypography(
                design: .rounded,
                digitDesign: .rounded,
                displayWeight: .light,
                titleWeight: .medium,
                bodyWeight: .regular,
                captionWeight: .regular,
                captionCase: .uppercase,
                captionTracking: 1.1,
                symbolWeight: .regular
            ),
            panel: .glass(tint: teal.opacity(0.32), clear: false, edge: glow.opacity(0.18)),
            panelCorner: 30,
            control: .glass(tint: teal.opacity(0.26), clear: false, edge: glow.opacity(0.2)),
            controlInk: ink,
            accentSurface: .glass(tint: accent.opacity(0.85), clear: false, edge: nil),
            onAccent: deep,
            sheet: backdrop.mix(with: teal, by: 0.18),
            chip: ChipLook(
                name: .init(size: 13.5, weight: .medium, design: .rounded),
                time: .init(size: 13.5, weight: .light, design: .rounded, monospacedDigits: true),
                detail: .init(size: 11.5, weight: .regular, design: .rounded),
                horizontalPadding: 10,
                corner: 100,
                surface: .solid(fill: Color(hex: 0x031720).opacity(0.78), edge: glow.opacity(0.32)),
                selectedSurface: .solid(fill: accent, edge: nil),
                nameColor: ink,
                timeColor: Color(hex: 0xA6E4EC),
                detailColor: mist,
                shiftedTimeColor: Color(hex: 0xFFCF8A),
                selectedInk: deep
            ),
            bead: BeadLook(
                body: ink,
                shade: Color(hex: 0x6FA7B5),
                highlight: .white,
                outline: Color(hex: 0x021018),
                outlineWidth: 1.1,
                halo: accent.opacity(0.5)
            ),
            tape: TapeLook(
                tick: Color(hex: 0xCFF6FF),
                label: mist,
                labelWeight: .regular,
                labelDesign: .rounded,
                hourWidth: 1.25,
                quarterWidth: 1,
                needle: .capsule
            ),
            swatch: SwatchLook(
                ocean: Color(hex: 0x0E5F6E),
                land: Color(hex: 0x17222A),
                night: Color(hex: 0x01070D).opacity(0.62),
                rim: glow.opacity(0.7),
                finish: .glow
            )
        )
    }()
}
