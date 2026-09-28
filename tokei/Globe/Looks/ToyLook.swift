import SwiftUI
import simd

struct ToyLook {
    var backdrop: SIMD4<Float>
    var oceanDeep: SIMD4<Float>
    var oceanShallow: SIMD4<Float>
    var oceanNight: SIMD4<Float>
    var foam: SIMD4<Float>
    var landLow: SIMD4<Float>
    var landHigh: SIMD4<Float>
    var landNight: SIMD4<Float>
    var cityLight: SIMD4<Float>
    var twilight: SIMD4<Float>
    var fill: SIMD4<Float>
    var rim: SIMD4<Float>
    var shine: SIMD4<Float>
    var wrap: Float
    var gloss: Float
    var clearcoat: Float
    var sheen: Float
    var shallowWidth: Float
    var foamWidth: Float
    var shadowLength: Float
    var shadowStrength: Float
    var softbox: Float
    var nightReflection: Float
    var form: Float
    var rimLight: Float
    var ledSize: Float
    var ledGlow: Float
    var twilightWidth: Float
    var landGloss: Float

    static let standard = ToyLook(
        backdrop: .linear(0x08192B),
        oceanDeep: .linear(0x0A83B0),
        oceanShallow: .linear(0x2ED3D3),
        oceanNight: .linear(0x06243B),
        foam: .linear(0xE3FFFB),
        landLow: .linear(0xFF3D8B),
        landHigh: .linear(0xFF8CC0),
        landNight: .linear(0x3B2358),
        cityLight: .linear(0xFFD36B),
        twilight: .linear(0xFF7A59),
        fill: .linear(0x6FC9E6),
        rim: .linear(0x9EF0F0),
        shine: .linear(0xFFF8EE),
        wrap: 0.35,
        gloss: 3000,
        clearcoat: 2.2,
        sheen: 0.05,
        shallowWidth: 0.5,
        foamWidth: 0.1,
        shadowLength: 0.45,
        shadowStrength: 0.45,
        softbox: 7,
        nightReflection: 0.12,
        form: 0.18,
        rimLight: 2.5,
        ledSize: 0.35,
        ledGlow: 1,
        twilightWidth: 0.16,
        landGloss: 500
    )
}

extension SceneLook {
    static let toy = SceneLook(
        name: "Toy",
        backdrop: ToyLook.standard.backdrop.xyz,
        accent: Color(red: 1, green: 0.85, blue: 0.36),
        effects: .toy,
        sound: .soft,
        mesh: MeshLook(fragment: "toyFragment", background: "toyBackground", shape: .puffy, parameters: ToyLook.standard)
    )
}

extension SoundTimbre {
    static let soft = SoundTimbre(id: "soft") { kind, voice in
        var voice = voice
        voice.noise *= 0.35
        voice.attack = max(voice.attack * 1.6, 0.002)
        switch kind {
        case .tick, .dayTick:
            voice.startFrequency *= 0.72
            voice.endFrequency *= 0.72
            voice.overtone = 0.45
            voice.gain *= 0.9
        case .press:
            voice.startFrequency *= 0.9
            voice.endFrequency *= 0.8
            voice.glide *= 1.5
            voice.overtone = 0.35
        case .release:
            voice.startFrequency *= 0.85
            voice.endFrequency *= 0.85
            voice.vibratoDepth *= 1.4
            voice.vibratoRate *= 0.75
            voice.vibratoDecay *= 1.5
            voice.decay *= 1.25
        case .pop:
            voice.startFrequency *= 0.8
            voice.endFrequency *= 0.9
            voice.glide *= 1.8
            voice.vibratoDepth = 0.05
            voice.vibratoRate = 24
            voice.vibratoDecay = 0.04
            voice.overtone = 0.3
            voice.decay *= 1.3
            voice.duration *= 1.3
        case .inflate:
            voice.endFrequency *= 1.15
            voice.vibratoDepth = 0.035
            voice.vibratoRate = 9
            voice.vibratoDecay = 0.3
        default:
            break
        }
        return voice
    }
}

extension EffectTuning {
    static let toy = EffectTuning(
        press: Press(
            dentDepth: 0.085,
            dentRadius: 0.17,
            dentShade: 6,
            frost: 0,
            cracks: 0,
            squash: 0.035,
            pressSpring: Spring(duration: 0.22, bounce: 0.25),
            releaseSpring: Spring(duration: 0.6, bounce: 0.6)
        ),
        pop: Pop(height: 0.05, radius: 0.075, glow: 0.6, spring: Spring(duration: 0.5, bounce: 0.6)),
        ripple: Ripple(tilt: 0.12, landShare: 0, flash: 0.4, displacement: 0, wavelength: 0.09, speed: 1, decay: 2, duration: 1.7),
        fling: Fling(stretchPerSpeed: 0.014, maximumStretch: 0.07, spring: Spring(duration: 0.5, bounce: 0.6)),
        flightArc: 0.65,
        inflate: Spring(duration: 0.9, bounce: 0.4),
        drag: .init(follow: Spring(duration: 0.2, bounce: 0.35), grainSharpness: 0.2)
    )
}
