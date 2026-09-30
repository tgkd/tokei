import SwiftUI

extension InterfaceLook {
    static let sakura: InterfaceLook = {
        let accent = SceneStyle.sakura.accent
        let ink = Color(hex: 0x3A2A33)
        let muted = Color(hex: 0x8C6B78)
        let blush = Color(hex: 0xF7D9E1)
        return InterfaceLook(
            colorScheme: .light,
            ink: ink,
            secondaryInk: muted,
            typography: InterfaceTypography(
                displayWeight: .light,
                titleWeight: .medium,
                bodyWeight: .regular,
                captionWeight: .medium,
                captionCase: .uppercase,
                captionTracking: 1.4,
                symbolWeight: .regular
            ),
            panel: .glass(tint: blush.opacity(0.35), clear: false, edge: .white.opacity(0.7)),
            panelCorner: 30,
            control: .glass(tint: blush.opacity(0.25), clear: false, edge: .white.opacity(0.7)),
            controlInk: ink,
            accentSurface: .glass(tint: accent.opacity(0.9), clear: false, edge: nil),
            onAccent: .white,
            sheet: Color(hex: 0xFBF4F6),
            chip: ChipLook(
                name: .init(size: 13, weight: .semibold),
                time: .init(size: 13, weight: .regular, monospacedDigits: true),
                detail: .init(size: 11, weight: .medium),
                horizontalPadding: 10,
                verticalPadding: 5,
                corner: 100,
                surface: .solid(fill: Color(hex: 0xFFFBFC).opacity(0.95), edge: Color(hex: 0xEBBBC8)),
                selectedSurface: .solid(fill: accent, edge: nil),
                nameColor: ink,
                timeColor: muted,
                detailColor: muted,
                shiftedTimeColor: accent,
                selectedInk: .white
            ),
            bead: BeadLook(
                body: .white,
                shade: Color(hex: 0xF2B6C4),
                highlight: .white,
                outline: ink.opacity(0.7),
                outlineWidth: 1,
                halo: accent.opacity(0.35)
            ),
            tape: TapeLook(
                tick: ink,
                label: muted,
                labelWeight: .medium,
                hourWidth: 1.25,
                quarterWidth: 1,
                needle: .pin
            ),
            swatch: SwatchLook(
                ocean: Color(hex: 0x1F4577),
                land: Color(hex: 0xF2ACBC),
                night: Color(hex: 0x2B2F5C).opacity(0.45),
                rim: ink.opacity(0.3),
                finish: .blossom
            )
        )
    }()
}
