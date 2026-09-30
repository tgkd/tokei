import SwiftUI
import simd

struct AbyssLook {
    var backdrop: SIMD4<Float>
    var backdropGlow: SIMD4<Float>
    var abyss: SIMD4<Float>
    var openSea: SIMD4<Float>
    var shelf: SIMD4<Float>
    var shallows: SIMD4<Float>
    var nightAbyss: SIMD4<Float>
    var nightShelf: SIMD4<Float>
    var land: SIMD4<Float>
    var landHigh: SIMD4<Float>
    var nightLand: SIMD4<Float>
    var rim: SIMD4<Float>
    var cityLight: SIMD4<Float>
    var plankton: SIMD4<Float>
    var spark: SIMD4<Float>
    var sparkHalo: SIMD4<Float>
    var moon: SIMD4<Float>
    var twilight: SIMD4<Float>
    var limb: SIMD4<Float>
    var shelfWidth: Float
    var shelfReach: Float
    var abyssReach: Float
    var isobaths: Float
    var isobathSpacing: Float
    var rimWidth: Float
    var rimStrength: Float
    var planktonSpacing: Float
    var planktonDensity: Float
    var planktonSize: Float
    var planktonGlow: Float
    var sparkSpacing: Float
    var sparkDensity: Float
    var sparkSize: Float
    var sparkGlow: Float
    var recovery: Float
    var twilightWidth: Float
    var sheen: Float
    var glitter: Float
    var limbStrength: Float
    var cityGlow: Float
    var relief: Float
    var ringWidth: Float
    var reserved: Float = 0

    static let standard = AbyssLook(
        backdrop: .linear(0x020912),
        backdropGlow: .linear(0x0E4A5C),
        abyss: .linear(0x052A3B),
        openSea: .linear(0x0A4458),
        shelf: .linear(0x117585),
        shallows: .linear(0x33BAB4),
        nightAbyss: .linear(0x01070D),
        nightShelf: .linear(0x04323A),
        land: .linear(0x0B1217),
        landHigh: .linear(0x1B2A33),
        nightLand: .linear(0x070C11),
        rim: .linear(0x8BEFFF),
        cityLight: .linear(0xFFCF8A),
        plankton: .linear(0x5DE8F0),
        spark: .linear(0xD2FFFF) * 2.6,
        sparkHalo: .linear(0x1E9BFF) * 1.5,
        moon: .linear(0xCFF3FF),
        twilight: .linear(0x5B6FC0),
        limb: .linear(0x3FC6E0),
        shelfWidth: 0.9,
        shelfReach: 2.5,
        abyssReach: 12,
        isobaths: 0.35,
        isobathSpacing: 0.6,
        rimWidth: 0.08,
        rimStrength: 1.2,
        planktonSpacing: 9,
        planktonDensity: 0.5,
        planktonSize: 0.55,
        planktonGlow: 0.9,
        sparkSpacing: 6,
        sparkDensity: 0.45,
        sparkSize: 0.45,
        sparkGlow: 2.5,
        recovery: 3.5,
        twilightWidth: 0.04,
        sheen: 1,
        glitter: 3,
        limbStrength: 0.45,
        cityGlow: 0.7,
        relief: 0.6,
        ringWidth: 0.35
    )
}

extension SceneLook {
    static let abyss = SceneLook(
        name: "Abyss",
        backdrop: AbyssLook.standard.backdrop.xyz,
        accent: Color(red: 0.36, green: 0.93, blue: 0.87),
        effects: .abyss,
        sound: .abyss,
        mesh: MeshLook(
            fragment: "abyssFragment",
            background: "abyssBackground",
            shape: .molten,
            parameters: AbyssLook.standard,
            snow: SnowSettings(recovery: Double(AbyssLook.standard.recovery))
        )
    )
}

extension EffectTuning {
    static let abyss = EffectTuning(
        press: Press(
            dentDepth: 0,
            dentRadius: 0.12,
            dentShade: 0,
            frost: 0,
            cracks: 0,
            squash: 0.006,
            pressSpring: Spring(duration: 0.22, bounce: 0),
            releaseSpring: Spring(duration: 0.5, bounce: 0.3)
        ),
        pop: Pop(height: 0.006, radius: 0.05, glow: 0.5, spring: Spring(duration: 0.4, bounce: 0.3)),
        ripple: Ripple(tilt: 0.03, landShare: 0, flash: 1, displacement: 0, wavelength: 0.06, speed: 0.75, decay: 1.6, duration: 2),
        fling: Fling(stretchPerSpeed: 0.004, maximumStretch: 0.02, spring: Spring(duration: 0.35, bounce: 0.35)),
        flightArc: 0.45,
        inflate: Spring(duration: 0.9, bounce: 0.15),
        drag: .init(follow: Spring(duration: 0.2, bounce: 0.1), trailWidth: 1.2, trailHold: 0.15, grainSpacing: 14, grainSharpness: 0.3)
    )
}
