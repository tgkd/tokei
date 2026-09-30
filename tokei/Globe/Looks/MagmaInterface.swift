import SwiftUI

extension InterfaceLook {
    static let magma: InterfaceLook = {
        let accent = SceneStyle.magma.accent
        let ink = Color(hex: 0xFBEEE4)
        let ash = Color(hex: 0xB7A396)
        let slab = Color(hex: 0x1E1817)
        let basalt = Color(hex: 0x2C2422)
        let bedrock = Color(hex: 0x070404)
        let glow = Color(hex: 0xFF4D0D)
        let molten = Color(hex: 0xFFB229)
        let char = Color(hex: 0x1A0C07)
        return InterfaceLook(
            colorScheme: .dark,
            ink: ink,
            secondaryInk: ash,
            typography: InterfaceTypography(
                digitWidth: .expanded,
                displayWeight: .heavy,
                titleWeight: .bold,
                bodyWeight: .medium,
                captionWeight: .semibold,
                captionCase: .uppercase,
                captionTracking: 1.2,
                symbolWeight: .bold,
                engraved: true
            ),
            panel: .raised(fill: slab, base: bedrock, depth: 4, edge: glow.opacity(0.3)),
            panelCorner: 26,
            control: .raised(fill: basalt, base: bedrock, depth: 3, edge: glow.opacity(0.24)),
            controlInk: ink,
            accentSurface: .raised(fill: accent, base: accent.mix(with: .black, by: 0.5), depth: 3, edge: molten.opacity(0.55)),
            onAccent: legibleInk(on: accent, dark: char),
            sheet: slab.mix(with: .black, by: 0.2),
            chip: ChipLook(
                name: .init(size: 13, weight: .bold),
                time: .init(size: 13, weight: .semibold, monospacedDigits: true),
                detail: .init(size: 11, weight: .semibold),
                horizontalPadding: 9,
                verticalPadding: 5,
                corner: 7,
                surface: .solid(fill: Color(hex: 0x140F0E).opacity(0.9), edge: glow.opacity(0.5)),
                selectedSurface: .raised(fill: accent, base: accent.mix(with: .black, by: 0.5), depth: 2, edge: molten.opacity(0.7)),
                nameColor: ink,
                timeColor: ash,
                detailColor: ash.opacity(0.85),
                shiftedTimeColor: molten,
                selectedInk: char
            ),
            bead: BeadLook(
                body: molten,
                shade: glow,
                highlight: Color(hex: 0xFFF1CF),
                outline: bedrock,
                outlineWidth: 1.2,
                halo: glow.opacity(0.55)
            ),
            tape: TapeLook(
                tick: ink,
                label: ash,
                labelWeight: .semibold,
                hourWidth: 2,
                quarterWidth: 1.25,
                needle: .chunky,
                needleOutline: bedrock
            ),
            swatch: SwatchLook(
                ocean: Color(hex: 0x050608),
                land: Color(hex: 0x3A3330),
                night: Color(hex: 0x0A0808).opacity(0.6),
                rim: Color(hex: 0xFF4D0D),
                finish: .ember
            )
        )
    }()
}
