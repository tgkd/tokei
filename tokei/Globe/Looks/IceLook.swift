import SwiftUI
import simd

struct IceLook {
    var backdrop: SIMD4<Float>
    var deepWater: SIMD4<Float>
    var shelfWater: SIMD4<Float>
    var nightWater: SIMD4<Float>
    var snow: SIMD4<Float>
    var snowShade: SIMD4<Float>
    var packedSnow: SIMD4<Float>
    var glacier: SIMD4<Float>
    var glacierGlow: SIMD4<Float>
    var floe: SIMD4<Float>
    var nightLand: SIMD4<Float>
    var cityLight: SIMD4<Float>
    var twilight: SIMD4<Float>
    var rim: SIMD4<Float>
    var aurora: SIMD4<Float>
    var frost: SIMD4<Float>
    var sparkle: Float
    var sparkleSharpness: Float
    var sparkleScatter: Float
    var glitter: Float
    var packIce: Float
    var floeSize: Float
    var wallGlow: Float
    var striations: Float
    var snowCover: Float
    var snowRecovery: Float
    var snowDepth: Float
    var snowRim: Float
    var auroraStrength: Float
    var twilightWidth: Float
    var frostBloom: Float
    var reserved: Float = 0

    static let standard = IceLook(
        backdrop: .linear(0x080B10),
        deepWater: .linear(0x0C1622),
        shelfWater: .linear(0x17293B),
        nightWater: .linear(0x05080D),
        snow: .linear(0xDCE5EE),
        snowShade: .linear(0x7890AE),
        packedSnow: .linear(0x9DB4CF),
        glacier: .linear(0x1E3F60),
        glacierGlow: .linear(0x5E97C6),
        floe: .linear(0xB8C8D8),
        nightLand: .linear(0x18212D),
        cityLight: .linear(0xD6E8FF),
        twilight: .linear(0x8C9CC8),
        rim: .linear(0x7FA6CF),
        aurora: .linear(0x62B6EC),
        frost: .linear(0xDDEBF7),
        sparkle: 4,
        sparkleSharpness: 150,
        sparkleScatter: 0.55,
        glitter: 2.5,
        packIce: 1.2,
        floeSize: 0.011,
        wallGlow: 0.5,
        striations: 0.12,
        snowCover: 1,
        snowRecovery: 5,
        snowDepth: 0.012,
        snowRim: 0.5,
        auroraStrength: 0.1,
        twilightWidth: 0.035,
        frostBloom: 0.8
    )
}

extension SceneLook {
    static let ice = SceneLook(
        name: "Ice",
        backdrop: IceLook.standard.backdrop.xyz,
        accent: Color(red: 0.62, green: 0.745, blue: 0.867),
        effects: .ice,
        sound: .glass,
        mesh: MeshLook(
            fragment: "iceFragment",
            background: "iceBackground",
            shape: .stepped,
            parameters: IceLook.standard,
            snow: SnowSettings(recovery: Double(IceLook.standard.snowRecovery))
        )
    )
}

extension EffectTuning {
    static let ice = EffectTuning(
        press: Press(
            dentDepth: 0.014,
            dentRadius: 0.13,
            dentShade: 0,
            frost: 0,
            cracks: 0.85,
            squash: 0.007,
            pressSpring: Spring(duration: 0.12, bounce: 0),
            releaseSpring: Spring(duration: 0.22, bounce: 0.25)
        ),
        pop: Pop(height: 0.012, radius: 0.045, glow: 0.4, spring: Spring(duration: 0.22, bounce: 0.35)),
        ripple: Ripple(tilt: 0.05, landShare: 0.35, flash: 0.9, displacement: 0, wavelength: 0.06, speed: 1.4, decay: 4, duration: 0.8),
        fling: Fling(stretchPerSpeed: 0.003, maximumStretch: 0.015, spring: Spring(duration: 0.16, bounce: 0.45)),
        flightArc: 0.45,
        inflate: Spring(duration: 0.5, bounce: 0.12),
        drag: .init(follow: Spring(duration: 0.12, bounce: 0.05), grainSharpness: 0.75)
    )
}
