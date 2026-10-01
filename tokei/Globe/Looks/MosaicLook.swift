import SwiftUI
import simd

struct MosaicLook {
    var backdrop: SIMD4<Float>
    var backdropShade: SIMD4<Float>
    var shard: SIMD4<Float>
    var grout: SIMD4<Float>
    var groutNight: SIMD4<Float>
    var cobalt: SIMD4<Float>
    var turquoise: SIMD4<Float>
    var seaWhite: SIMD4<Float>
    var ochre: SIMD4<Float>
    var orange: SIMD4<Float>
    var olive: SIMD4<Float>
    var lemon: SIMD4<Float>
    var gold: SIMD4<Float>
    var terracottaBack: SIMD4<Float>
    var nightGlaze: SIMD4<Float>
    var cityLight: SIMD4<Float>
    var twilight: SIMD4<Float>
    var tileSize: Float
    var tileTilt: Float
    var glazeGloss: Float
    var glazeSpec: Float
    var groutWidth: Float
    var coastRow: Float
    var goldChance: Float
    var goldGloss: Float
    var flipTime: Float
    var flipJitter: Float
    var funnel: Float
    var pressDepth: Float
    var recovery: Float
    var flipThreshold: Float
    var flipSpread: Float
    var rattle: Float
    var inflateSpan: Float
    var terminatorWidth: Float
    var cityGlow: Float
    var patternSize: Float
    var patternTurns: Float
    var patternGrout: Float
    var vignette: Float
    var reserved: Float = 0

    static let standard = MosaicLook(
        backdrop: .linear(0xA84A2F),
        backdropShade: .linear(0x7E3420),
        shard: .linear(0xF2EEE6),
        grout: .linear(0xD8D1C3),
        groutNight: .linear(0x2A2622),
        cobalt: .linear(0x1F4FA8),
        turquoise: .linear(0x2FA5B5),
        seaWhite: .linear(0xEEF3F4),
        ochre: .linear(0xD99A2B),
        orange: .linear(0xE0662E),
        olive: .linear(0x7C8A2E),
        lemon: .linear(0xE9CF4A),
        gold: .linear(0xD8A93B),
        terracottaBack: .linear(0xB5603A),
        nightGlaze: .linear(0x141A2A),
        cityLight: .linear(0xFFC27A),
        twilight: .linear(0xF0A070),
        tileSize: 2.7,
        tileTilt: 0.1,
        glazeGloss: 300,
        glazeSpec: 0.5,
        groutWidth: 0.06,
        coastRow: 0.9,
        goldChance: 0.04,
        goldGloss: 900,
        flipTime: 0.25,
        flipJitter: 0.08,
        funnel: 0.35,
        pressDepth: 0.012,
        recovery: 4,
        flipThreshold: 0.25,
        flipSpread: 0.5,
        rattle: 12,
        inflateSpan: 1.1,
        terminatorWidth: 0.02,
        cityGlow: 0.8,
        patternSize: 22,
        patternTurns: 6,
        patternGrout: 0.07,
        vignette: 0.25
    )
}

extension SceneLook {
    static let mosaic = SceneLook(
        name: "Mosaic",
        backdrop: MosaicLook.standard.backdrop.xyz,
        accent: Color(red: 0.12, green: 0.31, blue: 0.66),
        effects: .mosaic,
        sound: .mosaic,
        mesh: MeshLook(
            fragment: "mosaicFragment",
            background: "mosaicBackground",
            shape: .puffy,
            parameters: MosaicLook.standard,
            snow: SnowSettings(recovery: Double(MosaicLook.standard.recovery), footprints: false)
        ),
        popEcho: MosaicSound.cascadeHaptics
    )
}

extension EffectTuning {
    static let mosaic = EffectTuning(
        press: Press(
            dentDepth: 0.012,
            dentRadius: 0.12,
            dentShade: 2,
            frost: 0,
            cracks: 0,
            squash: 0.004,
            pressSpring: Spring(duration: 0.16, bounce: 0),
            releaseSpring: Spring(duration: 0.28, bounce: 0.15)
        ),
        pop: Pop(height: 0.006, radius: 0.04, glow: 0, spring: Spring(duration: 0.4, bounce: 0.2)),
        ripple: Ripple(tilt: 0, landShare: 1, flash: 0, displacement: 0, wavelength: 0.06, speed: 0.5, decay: 2.0, duration: 2.4),
        fling: Fling(stretchPerSpeed: 0.004, maximumStretch: 0.02, spring: Spring(duration: 0.45, bounce: 0.25)),
        flightArc: 0.5,
        inflate: Spring(duration: 1.4, bounce: 0.1),
        drag: .init(follow: Spring(duration: 0.16, bounce: 0.2), trailWidth: 1.2, trailHold: 0.5, grainSpacing: 10, grainSharpness: 0.7)
    )
}
