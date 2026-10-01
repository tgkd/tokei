import SwiftUI

extension InterfaceLook {
    static let repeater: InterfaceLook = {
        let accent = SceneStyle.repeater.accent
        let ink = Color(hex: 0x1E2B3A)
        let silver = Color(hex: 0xD9DDE3)
        return InterfaceLook(
            colorScheme: .light,
            ink: ink,
            secondaryInk: Color(hex: 0x6B7480),
            typography: InterfaceTypography(
                displayWeight: .light,
                titleWeight: .medium,
                bodyWeight: .regular,
                captionWeight: .medium,
                captionCase: .uppercase,
                captionTracking: 1.2,
                symbolWeight: .regular
            ),
            panel: .glass(tint: Color(hex: 0xF7F5F0).opacity(0.75), clear: false, edge: Color(hex: 0x9AA1AC).opacity(0.4)),
            panelCorner: 28,
            control: .glass(tint: Color(hex: 0xF7F5F0).opacity(0.7), clear: false, edge: Color(hex: 0x9AA1AC).opacity(0.45)),
            controlInk: ink,
            accentSurface: .raised(fill: accent, base: accent.mix(with: .black, by: 0.45), depth: 2.5, edge: nil),
            onAccent: legibleInk(on: accent, dark: ink),
            sheet: Color(hex: 0xF4F2EC),
            chip: ChipLook(
                name: .init(size: 13, weight: .semibold),
                time: .init(size: 13, weight: .regular, monospacedDigits: true),
                detail: .init(size: 11, weight: .medium),
                horizontalPadding: 10,
                verticalPadding: 5,
                corner: 8,
                surface: .solid(fill: Color(hex: 0xF7F5F0).opacity(0.94), edge: Color(hex: 0x9AA1AC).opacity(0.6)),
                selectedSurface: .raised(fill: accent, base: accent.mix(with: .black, by: 0.45), depth: 2, edge: nil),
                nameColor: ink,
                timeColor: Color(hex: 0x6B7480),
                detailColor: Color(hex: 0x6B7480),
                shiftedTimeColor: Color(hex: 0xB07A22),
                selectedInk: ink
            ),
            bead: BeadLook(
                body: Color(hex: 0xE8EAEE),
                shade: Color(hex: 0x8A909A),
                highlight: .white,
                outline: Color(hex: 0x2A3040),
                outlineWidth: 1.1,
                halo: accent.opacity(0.5)
            ),
            tape: TapeLook(
                tick: ink,
                label: Color(hex: 0x6B7480),
                labelWeight: .medium,
                hourWidth: 1.5,
                quarterWidth: 1,
                needle: .pin,
                needleOutline: Color(hex: 0x9C7C3C)
            ),
            swatch: SwatchLook(
                ocean: Color(hex: 0x2E5E8C),
                land: silver,
                night: Color(hex: 0x0E1B30).opacity(0.6),
                rim: Color(hex: 0xE8C46A),
                finish: .enamel
            )
        )
    }()
}
