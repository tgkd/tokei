import SwiftUI
import simd

struct ChromeLook {
    var backdrop: SIMD4<Float>
    var sea: SIMD4<Float>
    var land: SIMD4<Float>
    var sun: SIMD4<Float>
    var key: SIMD4<Float>
    var fill: SIMD4<Float>
    var strip: SIMD4<Float>
    var warm: SIMD4<Float>
    var cool: SIMD4<Float>
    var sky: SIMD4<Float>
    var ground: SIMD4<Float>
    var wall: SIMD4<Float>
    var night: SIMD4<Float>
    var twilight: SIMD4<Float>
    var ember: SIMD4<Float>
    var molten: SIMD4<Float>
    var seaBlur: Float
    var landBlur: Float
    var sheen: Float
    var sheenSpread: Float
    var bevel: Float
    var lift: Float
    var groove: Float
    var grooveDepth: Float
    var meniscus: Float
    var halo: Float
    var swell: Float
    var swellLength: Float
    var swellReach: Float
    var brush: Float
    var brushDepth: Float
    var dusk: Float

    static let standard = ChromeLook(
        backdrop: .linear(0x0B1328),
        sea: .linear(0xAFBBCB),
        land: .linear(0xF1D7A4),
        sun: .radiance(0xFFF3E0, 4, 0.05),
        key: .radiance(0xFFFFFF, 3, 0.32),
        fill: .radiance(0xDDE6F5, 0.5, 0.6),
        strip: .radiance(0xFFFFFF, 2.5),
        warm: .radiance(0xFFB36B, 2.2),
        cool: .radiance(0x9CC3FF, 2.2),
        sky: .radiance(0xDCE3EE, 0.22),
        ground: .radiance(0x8A8F99, 0.08, -0.1),
        wall: .radiance(0x3558B0, 0.45, 0.8),
        night: .radiance(0x4F78D0, 0.06, 0.3),
        twilight: .linear(0xFFC08A),
        ember: .radiance(0xFF9A3C, 2, 0.0045),
        molten: .radiance(0xFFD9B0, 1, 1.6),
        seaBlur: 0,
        landBlur: 0.16,
        sheen: 0.35,
        sheenSpread: 16,
        bevel: MoltenShape.bevel,
        lift: Float(ToyTerrain.plateHeight),
        groove: 0.035,
        grooveDepth: 0.8,
        meniscus: 0.15,
        halo: 6,
        swell: 0.025,
        swellLength: 0.7,
        swellReach: 1.2,
        brush: 1500,
        brushDepth: 0.3,
        dusk: 0.35
    )
}

private extension SIMD4 where Scalar == Float {
    static func radiance(_ hex: UInt32, _ intensity: Float, _ w: Float = 1) -> SIMD4<Float> {
        SIMD4(SIMD3.linear(hex) * intensity, w)
    }
}

extension SceneLook {
    static let chrome = SceneLook(
        name: "Chrome",
        backdrop: ChromeLook.standard.backdrop.xyz,
        accent: Color(red: 0.91, green: 0.82, blue: 0.65),
        effects: .chrome,
        sound: .metal,
        mesh: MeshLook(fragment: "chromeFragment", background: "chromeBackground", shape: .molten, parameters: ChromeLook.standard)
    )
}

extension EffectTuning {
    static let chrome = EffectTuning(
        press: Press(
            dentDepth: 0.07,
            dentRadius: 0.15,
            dentShade: 1,
            frost: 0,
            cracks: 0,
            squash: 0.045,
            pressSpring: Spring(duration: 0.35, bounce: 0),
            releaseSpring: Spring(duration: 0.9, bounce: 0.6)
        ),
        pop: Pop(height: 0.035, radius: 0.055, glow: 0.12, spring: Spring(duration: 0.6, bounce: 0.55)),
        ripple: Ripple(tilt: 0.25, landShare: 0, flash: 0, displacement: 0.004, wavelength: 0.07, speed: 0.75, decay: 1.6, duration: 2),
        fling: Fling(stretchPerSpeed: 0.013, maximumStretch: 0.07, spring: Spring(duration: 0.7, bounce: 0.55)),
        flightArc: 0.6,
        inflate: Spring(duration: 1.4, bounce: 0.15),
        drag: .init(follow: Spring(duration: 0.22, bounce: 0.45), grainSharpness: 0.6)
    )
}

extension SoundTimbre {
    static let metal = SoundTimbre(id: "metal") { kind, voice in
        var voice = voice
        voice.attack = min(voice.attack, 0.0015)
        voice.overtone *= 0.3
        voice.noise *= 0.5
        voice.bell = 0.55
        voice.gain *= 0.7
        switch kind {
        case .tick:
            voice.startFrequency *= 1.6
            voice.endFrequency *= 1.6
            voice.decay *= 2.5
            voice.duration = max(voice.duration, 0.07)
            voice.gain *= 0.8
        case .pop:
            voice.startFrequency = 1760
            voice.endFrequency = 1760
            voice.decay = 0.2
            voice.duration = 0.75
            voice.bell = 0.7
            voice.vibratoDepth = 0.004
            voice.vibratoRate = 5
            voice.vibratoDecay = 0.6
            voice.gain *= 0.9
        case .release:
            voice.startFrequency *= 1.6
            voice.endFrequency *= 1.6
            voice.vibratoRate *= 0.6
            voice.vibratoDecay *= 2
            voice.decay *= 2.5
            voice.duration = min(voice.duration * 2, 0.7)
        case .inflate:
            voice.startFrequency *= 2
            voice.endFrequency *= 2.6
            voice.glide *= 3
            voice.vibratoDepth = 0.015
            voice.vibratoRate = 7
            voice.vibratoDecay = 0.5
            voice.decay *= 2
            voice.duration = min(voice.duration * 2, 1)
        case .carve:
            voice.startFrequency *= 2.2
            voice.endFrequency *= 2.2
            voice.duration = min(voice.duration, 0.07)
        default:
            voice.startFrequency *= 2.2
            voice.endFrequency *= 2.2
            voice.decay *= 3
            voice.duration = min(voice.duration * 2.5, 0.6)
        }
        return voice
    }
}
