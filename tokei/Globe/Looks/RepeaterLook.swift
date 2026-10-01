import SwiftUI
import simd

struct RepeaterLook {
    var backdrop: SIMD4<Float>
    var backdropShade: SIMD4<Float>
    var sunray: SIMD4<Float>
    var enamelDeep: SIMD4<Float>
    var enamelShallow: SIMD4<Float>
    var silver: SIMD4<Float>
    var silverShade: SIMD4<Float>
    var gold: SIMD4<Float>
    var goldShade: SIMD4<Float>
    var nightEnamel: SIMD4<Float>
    var nightSilver: SIMD4<Float>
    var lume: SIMD4<Float>
    var twilight: SIMD4<Float>
    var ink: SIMD4<Float>
    var waveSpacing: Float
    var waveWobble: Float
    var waveDepth: Float
    var flankTilt: Float
    var flankSharpness: Float
    var flankStrength: Float
    var hobnailCell: Float
    var hobnailTilt: Float
    var highland: Float
    var wireWidth: Float
    var clearcoat: Float
    var clearcoatGloss: Float
    var lumeStrength: Float
    var lumeHalfTime: Float
    var lumeExponent: Float
    var terminatorWidth: Float
    var loupeRadius: Float
    var loupeMagnification: Float
    var loupeDepth: Float
    var sunrayLines: Float
    var sunraySheen: Float
    var chapterRing: Float
    var rimLight: Float
    var lineWidth: Float

    static let standard = RepeaterLook(
        backdrop: .linear(0xE9EAEC),
        backdropShade: .linear(0xBFC3C9),
        sunray: .linear(0xFFFFFF),
        enamelDeep: .linear(0x0C2A66),
        enamelShallow: .linear(0x2F63B8),
        silver: .linear(0xE6E7E9),
        silverShade: .linear(0x8E9299),
        gold: .linear(0xE2BC63),
        goldShade: .linear(0x8A6A2C),
        nightEnamel: .linear(0x0B1428),
        nightSilver: .linear(0x272C38),
        lume: .linear(0xA8F0B8),
        twilight: .linear(0xE8A06A),
        ink: .linear(0x1C2A4A),
        waveSpacing: 0.85,
        waveWobble: 0.3,
        waveDepth: 0.55,
        flankTilt: 0.5,
        flankSharpness: 70,
        flankStrength: 0.9,
        hobnailCell: 1.1,
        hobnailTilt: 0.32,
        highland: 0.35,
        wireWidth: 0.12,
        clearcoat: 0.04,
        clearcoatGloss: 700,
        lumeStrength: 0.9,
        lumeHalfTime: 1.0,
        lumeExponent: 1.4,
        terminatorWidth: 0.02,
        loupeRadius: 0.18,
        loupeMagnification: 1.8,
        loupeDepth: 0.03,
        sunrayLines: 240,
        sunraySheen: 0.3,
        chapterRing: 1.08,
        rimLight: 0.2,
        lineWidth: 0.2
    )
}

extension SceneLook {
    static let repeater: SceneLook = {
        var look = SceneLook(
            name: "Repeater",
            backdrop: RepeaterLook.standard.backdrop.xyz,
            accent: Color(red: 0.91, green: 0.77, blue: 0.42),
            effects: .repeater,
            sound: .repeater,
            mesh: MeshLook(
                fragment: "repeaterFragment",
                background: "repeaterBackground",
                shape: .stepped,
                parameters: RepeaterLook.standard
            )
        )
        look.strikes = StrikeSchedule(
            sequence: { hour, minute in
                RepeaterSound.strike(hour: hour, minute: minute)
            },
            duration: { hour, minute in
                RepeaterSound.strikeDuration(hour: hour, minute: minute)
            }
        )
        return look
    }()
}

extension EffectTuning {
    static let repeater = EffectTuning(
        press: Press(
            dentDepth: 0.03,
            dentRadius: 0.16,
            dentShade: 0.5,
            frost: 0,
            cracks: 0,
            squash: 0.006,
            pressSpring: Spring(duration: 0.24, bounce: 0),
            releaseSpring: Spring(duration: 0.5, bounce: 0.3),
            followHaptic: true,
            cutoff: 0.1
        ),
        pop: Pop(height: 0.012, radius: 0.05, glow: 0.4, spring: Spring(duration: 0.6, bounce: 0.2)),
        ripple: Ripple(tilt: 0.3, landShare: 0, flash: 0.5, displacement: 0.001, wavelength: 0.05, speed: 0.6, decay: 2.2, duration: 1.2),
        fling: Fling(stretchPerSpeed: 0.002, maximumStretch: 0.008, spring: Spring(duration: 0.5, bounce: 0.05)),
        flightArc: 0.35,
        inflate: Spring(duration: 0.8, bounce: 0.2)
    )
}
