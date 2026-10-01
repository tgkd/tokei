import SwiftUI

extension InterfaceLook {
    static let mosaic: InterfaceLook = {
        let accent = SceneStyle.mosaic.accent
        let ink = Color(hex: 0xFBF6EE)
        let blush = Color(hex: 0xF0D9C8)
        let clay = Color(hex: 0x8E3D26)
        let brick = Color(hex: 0x9C4429)
        let kiln = Color(hex: 0x5E2716)
        let cobalt = Color(hex: 0x1F4FA8)
        let glaze = Color(hex: 0xF7F4EE)
        return InterfaceLook(
            colorScheme: .dark,
            ink: ink,
            secondaryInk: blush,
            typography: InterfaceTypography(
                design: .serif,
                titleWeight: .semibold,
                captionCase: .uppercase,
                captionTracking: 1.4
            ),
            panel: .raised(fill: clay, base: kiln, depth: 3, edge: .white.opacity(0.25)),
            panelCorner: 18,
            control: .raised(fill: brick, base: kiln, depth: 2, edge: .white.opacity(0.2)),
            controlInk: ink,
            accentSurface: .raised(fill: accent, base: Color(hex: 0x14336E), depth: 2, edge: .white.opacity(0.4)),
            onAccent: .white,
            sheet: Color(hex: 0x7A3320),
            chip: ChipLook(
                name: .init(size: 13, weight: .bold, design: .serif),
                time: .init(size: 13, weight: .semibold, design: .serif, monospacedDigits: true),
                detail: .init(size: 11, weight: .regular, design: .serif),
                uppercasedName: true,
                corner: 4,
                surface: .solid(fill: glaze.opacity(0.97), edge: cobalt),
                selectedSurface: .solid(fill: cobalt, edge: .white),
                nameColor: cobalt,
                timeColor: Color(hex: 0x3C5A8C),
                detailColor: Color(hex: 0x6B7FA6),
                shiftedTimeColor: Color(hex: 0xE0662E),
                selectedInk: .white,
                flipsOnSelect: true
            ),
            bead: BeadLook(
                body: cobalt,
                shade: Color(hex: 0x14336E),
                highlight: Color(hex: 0x8FB0EA),
                outline: kiln,
                outlineWidth: 1.2,
                halo: cobalt.opacity(0.45)
            ),
            tape: TapeLook(
                tick: ink,
                label: blush,
                labelWeight: .semibold,
                labelDesign: .serif,
                hourWidth: 2,
                quarterWidth: 1.2,
                squareCaps: true,
                needle: .capsule
            ),
            swatch: SwatchLook(
                ocean: Color(hex: 0x1F4FA8),
                land: Color(hex: 0xD99A2B),
                night: Color(hex: 0x141A2A).opacity(0.5),
                rim: Color(hex: 0xF2EEE6),
                finish: .tiles
            )
        )
    }()
}
