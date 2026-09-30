import SwiftUI
import simd

struct MagmaLook {
    var backdrop: SIMD4<Float>
    var crust: SIMD4<Float>
    var crustShade: SIMD4<Float>
    var crustSheen: SIMD4<Float>
    var oxide: SIMD4<Float>
    var obsidian: SIMD4<Float>
    var obsidianSky: SIMD4<Float>
    var ember: SIMD4<Float>
    var flame: SIMD4<Float>
    var molten: SIMD4<Float>
    var whiteHot: SIMD4<Float>
    var nightCrust: SIMD4<Float>
    var cityLight: SIMD4<Float>
    var twilight: SIMD4<Float>
    var haze: SIMD4<Float>
    var plateScale: Float
    var plateDetail: Float
    var crackWidth: Float
    var detailWidth: Float
    var glowWidth: Float
    var emberDay: Float
    var emberNight: Float
    var pillow: Float
    var widening: Float
    var bleed: Float
    var coastGlow: Float
    var coastWidth: Float
    var seaGloss: Float
    var seaSheen: Float
    var glassScale: Float
    var summitGlow: Float
    var recovery: Float
    var twilightWidth: Float
    var rimLight: Float
    var eruption: Float
    var pulse: Float
    var fracture: Float
    var wrap: Float
    var reserved: Float = 0

    static let standard = MagmaLook(
        backdrop: .linear(0x0C0706),
        crust: .linear(0x2A2422),
        crustShade: .linear(0x0B0A0B),
        crustSheen: .linear(0x7F8DA3),
        oxide: .linear(0x4A2419),
        obsidian: .linear(0x050608),
        obsidianSky: .linear(0x4E4744),
        ember: .linear(0x7A1405),
        flame: .linear(0xFF4D0D),
        molten: .linear(0xFFB229),
        whiteHot: .linear(0xFFF1CF),
        nightCrust: .linear(0x0A0808),
        cityLight: .linear(0xFF9A3C),
        twilight: .linear(0xD06A4A),
        haze: .linear(0xB8421A),
        plateScale: 36,
        plateDetail: 3.4,
        crackWidth: 0.0016,
        detailWidth: 0.0007,
        glowWidth: 0.004,
        emberDay: 0.5,
        emberNight: 0.66,
        pillow: 0.08,
        widening: 1.6,
        bleed: 0.55,
        coastGlow: 1,
        coastWidth: 0.06,
        seaGloss: 20000,
        seaSheen: 1,
        glassScale: 3.2,
        summitGlow: 0.3,
        recovery: 7,
        twilightWidth: 0.02,
        rimLight: 0.35,
        eruption: 1,
        pulse: 0.8,
        fracture: 1,
        wrap: 0.15
    )
}

extension SceneLook {
    static let magma = SceneLook(
        name: "Magma",
        backdrop: MagmaLook.standard.backdrop.xyz,
        accent: Color(red: 1, green: 0.42, blue: 0.12),
        effects: .magma,
        sound: .magma,
        mesh: MeshLook(
            fragment: "magmaFragment",
            background: "magmaBackground",
            shape: .stepped,
            parameters: MagmaLook.standard,
            snow: SnowSettings(recovery: Double(MagmaLook.standard.recovery))
        )
    )
}

extension EffectTuning {
    static let magma = EffectTuning(
        press: Press(
            dentDepth: 0.018,
            dentRadius: 0.12,
            dentShade: 2,
            frost: 0,
            cracks: 0.9,
            squash: 0.005,
            pressSpring: Spring(duration: 0.34, bounce: 0),
            releaseSpring: Spring(duration: 0.7, bounce: 0.04)
        ),
        pop: Pop(height: 0.018, radius: 0.05, glow: 2.2, spring: Spring(duration: 0.9, bounce: 0.12)),
        ripple: Ripple(tilt: 0, landShare: 1, flash: 1, displacement: 0, wavelength: 0.05, speed: 0.55, decay: 1.4, duration: 1.8),
        fling: Fling(stretchPerSpeed: 0.0025, maximumStretch: 0.012, spring: Spring(duration: 0.55, bounce: 0.05)),
        flightArc: 0.4,
        inflate: Spring(duration: 1.2, bounce: 0.06),
        drag: .init(follow: Spring(duration: 0.32, bounce: 0), trailWidth: 1, trailHold: 0.2, grainSpacing: 16, grainSharpness: 0.35)
    )
}
