import SwiftUI
import simd

struct GardenLook {
    var backdrop: SIMD4<Float>
    var stain: SIMD4<Float>
    var gravel: SIMD4<Float>
    var gravelShade: SIMD4<Float>
    var mica: SIMD4<Float>
    var moss: SIMD4<Float>
    var mossLight: SIMD4<Float>
    var mossSheen: SIMD4<Float>
    var nightMoss: SIMD4<Float>
    var granite: SIMD4<Float>
    var lichen: SIMD4<Float>
    var pebble: SIMD4<Float>
    var moon: SIMD4<Float>
    var twilight: SIMD4<Float>
    var cityLight: SIMD4<Float>
    var rakeSpacing: Float
    var ringBand: Float
    var grooveTilt: Float
    var grooveShade: Float
    var grainFine: Float
    var grainCoarse: Float
    var grainContrast: Float
    var micaCell: Float
    var micaChance: Float
    var micaSharpness: Float
    var pebbleBand: Float
    var pebbleCell: Float
    var rockLevel: Float
    var mossSheenPower: Float
    var mossSheenStrength: Float
    var moonStrength: Float
    var terminatorWidth: Float
    var pressBend: Float
    var pressDepth: Float
    var rippleGlint: Float
    var stainCells: Float
    var stainStrength: Float
    var grainBackdrop: Float
    var markRecovery: Float

    static let standard = GardenLook(
        backdrop: .linear(0xCDB993),
        stain: .linear(0xA88F62),
        gravel: .linear(0xE4E1DA),
        gravelShade: .linear(0xB9B4A8),
        mica: .linear(0xFFFFFF),
        moss: .linear(0x3F5A2C),
        mossLight: .linear(0x5E7436),
        mossSheen: .linear(0xA7B86A),
        nightMoss: .linear(0x0E140C),
        granite: .linear(0x807E77),
        lichen: .linear(0xB5B08A),
        pebble: .linear(0x6E6A60),
        moon: .linear(0x8FA3C8),
        twilight: .linear(0xE8A66B),
        cityLight: .linear(0xFFB866),
        rakeSpacing: 1.3,
        ringBand: 7.8,
        grooveTilt: 0.22,
        grooveShade: 0.12,
        grainFine: 0.06,
        grainCoarse: 0.25,
        grainContrast: 0.12,
        micaCell: 0.15,
        micaChance: 0.04,
        micaSharpness: 400,
        pebbleBand: 0.25,
        pebbleCell: 0.12,
        rockLevel: 0.4,
        mossSheenPower: 4,
        mossSheenStrength: 0.25,
        moonStrength: 0.22,
        terminatorWidth: 0.02,
        pressBend: 0.6,
        pressDepth: 0.02,
        rippleGlint: 1.5,
        stainCells: 6,
        stainStrength: 0.18,
        grainBackdrop: 0.03,
        markRecovery: 6
    )
}

extension SceneLook {
    static let garden = SceneLook(
        name: "Garden",
        backdrop: GardenLook.standard.backdrop.xyz,
        accent: Color(red: 0.31, green: 0.42, blue: 0.18),
        effects: .garden,
        sound: .garden,
        mesh: MeshLook(
            fragment: "gardenFragment",
            background: "gardenBackground",
            shape: .stepped,
            parameters: GardenLook.standard,
            marks: MarkSettings(drag: .grooves(tines: 5), pop: .rings(radius: 0.05, spacing: 0.0125), width: 1.4, hold: 4, recovery: Double(GardenLook.standard.markRecovery))
        )
    )
}

extension EffectTuning {
    static let garden = EffectTuning(
        press: Press(
            dentDepth: 0.02,
            dentRadius: 0.11,
            dentShade: 3,
            frost: 0,
            cracks: 0,
            squash: 0.006,
            pressSpring: Spring(duration: 0.2, bounce: 0),
            releaseSpring: Spring(duration: 0.35, bounce: 0)
        ),
        pop: Pop(height: 0.008, radius: 0.04, glow: 0, spring: Spring(duration: 0.5, bounce: 0.1)),
        ripple: Ripple(tilt: 0, landShare: 1, flash: 1, displacement: 0, wavelength: 0.04, speed: 0.45, decay: 1.2, duration: 1.6),
        fling: Fling(stretchPerSpeed: 0.002, maximumStretch: 0.008, spring: Spring(duration: 0.4, bounce: 0.05)),
        flightArc: 0.4,
        inflate: Spring(duration: 1.6, bounce: 0.05),
        drag: .init(follow: Spring(duration: 0.18, bounce: 0), grainSpacing: 8, grainSharpness: 0.55)
    )
}
