import SwiftUI

extension InterfaceLook {
    static let knit: InterfaceLook = {
        let accent = SceneStyle.knit.accent
        return InterfaceLook(
            colorScheme: .dark,
            ink: Color(hex: 0xFBF3E6),
            secondaryInk: Color(hex: 0xE8CDB8),
            typography: InterfaceTypography(
                design: .rounded,
                digitDesign: .rounded,
                displayWeight: .semibold,
                titleWeight: .semibold,
                bodyWeight: .medium,
                captionCase: .uppercase,
                captionTracking: 1.0
            ),
            panel: .raised(fill: Color(hex: 0x6F3324), base: Color(hex: 0x4A2016), depth: 3, edge: accent.opacity(0.3)),
            panelCorner: 24,
            control: .raised(fill: Color(hex: 0x7D3A28), base: Color(hex: 0x4A2016), depth: 2, edge: accent.opacity(0.25)),
            controlInk: Color(hex: 0xFBF3E6),
            accentSurface: .raised(fill: accent, base: accent.mix(with: .black, by: 0.4), depth: 2, edge: Color(hex: 0xF4EEE2).opacity(0.5)),
            onAccent: legibleInk(on: accent, dark: Color(hex: 0x3A1A10)),
            sheet: Color(hex: 0x5E2B1E),
            chip: ChipLook(
                name: .init(size: 13, weight: .bold, design: .rounded),
                time: .init(size: 13, weight: .semibold, design: .rounded, monospacedDigits: true),
                detail: .init(size: 11, weight: .medium, design: .rounded),
                corner: 5,
                surface: .solid(fill: Color(hex: 0xF3EBDD).opacity(0.97), edge: Color(hex: 0xB5523B)),
                selectedSurface: .raised(fill: accent, base: accent.mix(with: .black, by: 0.4), depth: 2, edge: Color(hex: 0xB5523B)),
                nameColor: Color(hex: 0x5A2A1E),
                timeColor: Color(hex: 0x8A5A48),
                detailColor: Color(hex: 0x8A5A48),
                shiftedTimeColor: Color(hex: 0xB5523B),
                selectedInk: Color(hex: 0x3A1A10)
            ),
            bead: BeadLook(
                body: Color(hex: 0xD7A12F),
                shade: Color(hex: 0x9A6E1C),
                highlight: Color(hex: 0xF3D98C),
                outline: Color(hex: 0x4A2016),
                outlineWidth: 1.2,
                halo: accent.opacity(0.4)
            ),
            tape: TapeLook(
                tick: Color(hex: 0xFBF3E6),
                label: Color(hex: 0xE8CDB8),
                labelWeight: .medium,
                labelDesign: .rounded,
                hourWidth: 1.6,
                quarterWidth: 1,
                needle: .pin,
                needleOutline: Color(hex: 0x4A2016)
            ),
            swatch: SwatchLook(
                ocean: Color(hex: 0x34507A),
                land: Color(hex: 0xE8DCC4),
                night: Color(hex: 0x2B3352).opacity(0.5),
                rim: Color(hex: 0xD7A12F),
                finish: .yarn
            )
        )
    }()
}
