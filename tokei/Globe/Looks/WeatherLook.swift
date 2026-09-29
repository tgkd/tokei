import SwiftUI
import simd

struct WeatherLook {
    var backdrop: SIMD4<Float>
    var oceanDeep: SIMD4<Float>
    var oceanShallow: SIMD4<Float>
    var oceanNight: SIMD4<Float>
    var landLow: SIMD4<Float>
    var landHigh: SIMD4<Float>
    var landNight: SIMD4<Float>
    var coast: SIMD4<Float>
    var cityLight: SIMD4<Float>
    var twilight: SIMD4<Float>
    var cloudLit: SIMD4<Float>
    var cloudShade: SIMD4<Float>
    var cloudNight: SIMD4<Float>
    var storm: SIMD4<Float>
    var rain: SIMD4<Float>
    var snow: SIMD4<Float>
    var sleet: SIMD4<Float>
    var halo: SIMD4<Float>
    var sand: SIMD4<Float>
    var frost: SIMD4<Float>
    var biome: SIMD4<Float>
    var wrap: Float
    var shallowWidth: Float
    var coastWidth: Float
    var shadowStrength: Float
    var shadowReach: Float
    var cloudHeight: Float
    var cloudBulge: Float
    var cloudRim: Float
    var rainThreshold: Float
    var rainDensity: Float
    var recovery: Float
    var twilightWidth: Float
    var nightLights: Float
    var burstSpeed: Float
    var burstRadius: Float
    var toon: Float

    static let standard = WeatherLook(
        backdrop: .linear(0x0C1A33),
        oceanDeep: .linear(0x1D5796),
        oceanShallow: .linear(0x3584C2),
        oceanNight: .linear(0x0B1A33),
        landLow: .linear(0x7FB36A),
        landHigh: .linear(0xB2C98A),
        landNight: .linear(0x1C2B3A),
        coast: .linear(0xE9F2F7),
        cityLight: .linear(0xFFD27A),
        twilight: .linear(0xFF9B6A),
        cloudLit: .linear(0xFFFFFF),
        cloudShade: .linear(0xA9BCD4),
        cloudNight: .linear(0x33445E),
        storm: .linear(0x5873A0),
        rain: .linear(0x2F7BEA),
        snow: .linear(0xF4FAFF),
        sleet: .linear(0x9A8CF0),
        halo: .linear(0x5AA8F0),
        sand: .linear(0xD9C98F),
        frost: .linear(0xE8EEF2),
        biome: SIMD4(0.55, 0.7, 0, 0),
        wrap: 0.45,
        shallowWidth: 0.55,
        coastWidth: 0.08,
        shadowStrength: 0.3,
        shadowReach: 0.07,
        cloudHeight: Float(CloudShell.height),
        cloudBulge: 0.03,
        cloudRim: 0.35,
        rainThreshold: CloudMap.precipitationThreshold,
        rainDensity: 110,
        recovery: 6,
        twilightWidth: 0.09,
        nightLights: 1.2,
        burstSpeed: 1.6,
        burstRadius: 0.16,
        toon: 0.6
    )
}

extension SceneLook {
    static let weather = SceneLook(
        name: "Weather",
        backdrop: WeatherLook.standard.backdrop.xyz,
        accent: Color(red: 1, green: 0.8, blue: 0.3),
        effects: .weather,
        sound: .breeze,
        mesh: MeshLook(
            fragment: "weatherFragment",
            background: "weatherBackground",
            clouds: "weatherClouds",
            shape: .puffy,
            parameters: WeatherLook.standard,
            snow: SnowSettings(recovery: Double(WeatherLook.standard.recovery), footprints: false)
        )
    )
}

extension EffectTuning {
    static let weather = EffectTuning(
        press: Press(
            dentDepth: 0.045,
            dentRadius: 0.16,
            dentShade: 0,
            frost: 0,
            cracks: 0,
            squash: 0.02,
            pressSpring: Spring(duration: 0.25, bounce: 0.2),
            releaseSpring: Spring(duration: 0.7, bounce: 0.5)
        ),
        pop: Pop(height: 0.035, radius: 0.09, glow: 0.35, spring: Spring(duration: 0.6, bounce: 0.55)),
        ripple: Ripple(tilt: 0.1, landShare: 0, flash: 0.35, displacement: 0, wavelength: 0.09, speed: 0.9, decay: 1.8, duration: 1.8),
        fling: Fling(stretchPerSpeed: 0.01, maximumStretch: 0.05, spring: Spring(duration: 0.55, bounce: 0.55)),
        flightArc: 0.6,
        inflate: Spring(duration: 1.0, bounce: 0.35),
        drag: .init(follow: Spring(duration: 0.22, bounce: 0.3), trailWidth: 1.4, trailHold: 0.6, grainSpacing: 16, grainSharpness: 0.15)
    )
}

extension SoundTimbre {
    static let breeze = SoundTimbre(id: "breeze") { kind, voice in
        var voice = voice
        voice.attack = max(voice.attack * 2.5, 0.004)
        switch kind {
        case .tick, .dayTick:
            voice.startFrequency *= 0.62
            voice.endFrequency *= 0.62
            voice.overtone = 0.2
            voice.noise *= 0.5
            voice.gain *= 0.85
        case .press:
            voice.startFrequency = 260
            voice.endFrequency = 120
            voice.glide = 0.06
            voice.overtone = 0.1
            voice.noise = 0
            voice.hiss = 0.55
            voice.decay = 0.06
            voice.duration = 0.2
            voice.gain *= 0.9
        case .release:
            voice.startFrequency *= 0.8
            voice.endFrequency *= 0.7
            voice.vibratoDepth *= 0.6
            voice.hiss = 0.25
            voice.decay *= 1.3
        case .pop:
            voice.startFrequency = 1250
            voice.endFrequency = 520
            voice.glide = 0.018
            voice.overtone = 0.05
            voice.bell = 0.15
            voice.decay = 0.045
            voice.duration = 0.14
            voice.spread = 2
        case .inflate:
            voice.startFrequency *= 0.9
            voice.endFrequency *= 1.1
            voice.hiss = 0.35
            voice.vibratoDepth = 0.02
            voice.vibratoRate = 6
            voice.vibratoDecay = 0.4
        case .carve:
            voice.startFrequency *= 0.55
            voice.endFrequency *= 0.5
            voice.vibratoDepth = 0.03
            voice.overtone = 0.1
            voice.noise = 0.05
            voice.hiss = 1.4
            voice.decay *= 1.8
            voice.duration *= 1.6
            voice.gain *= 0.8
        default:
            break
        }
        return voice
    }
}
