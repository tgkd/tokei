import SwiftUI
import simd

struct PaperLook {
    var backdrop: SIMD4<Float>
    var seaDeep: SIMD4<Float>
    var seaOpen: SIMD4<Float>
    var seaShelf: SIMD4<Float>
    var seaShallow: SIMD4<Float>
    var seaCoast: SIMD4<Float>
    var landCoast: SIMD4<Float>
    var landLow: SIMD4<Float>
    var landMid: SIMD4<Float>
    var landHigh: SIMD4<Float>
    var landTop: SIMD4<Float>
    var surf: SIMD4<Float>
    var shade: SIMD4<Float>
    var golden: SIMD4<Float>
    var dusk: SIMD4<Float>
    var duskDeep: SIMD4<Float>
    var night: SIMD4<Float>
    var cityLight: SIMD4<Float>
    var pinhole: SIMD4<Float>
    var pop: SIMD4<Float>
    var seaSteps: SIMD4<Float>
    var landSteps: SIMD4<Float>
    var contourWobble: Float
    var deckle: Float
    var grain: Float
    var grainCell: Float
    var shadowReach: Float
    var shadowLimit: Float
    var shadowSoftness: Float
    var shadowStrength: Float
    var occlusionWidth: Float
    var occlusionStrength: Float
    var edgeLight: Float
    var edgeWidth: Float
    var surfOffset: Float
    var surfWidth: Float
    var daylightFloor: Float
    var goldenWidth: Float
    var duskDepth: Float
    var duskSaturation: Float
    var nightSaturation: Float
    var nightLift: Float
    var crestWidth: Float
    var crestLight: Float
    var creaseLine: Float
    var foldShadow: Float
    var limbShade: Float
    var outline: Float
    var keyLight: Float
    var effectRelief: Float
    var pinholeSpacing: Float
    var pinholeSize: Float
    var pinholeThreshold: Float
    var pinholeGlow: Float
    var glow: Float
    var halo: Float
    var popHeight: Float
    var popSize: Float
    var popPetals: Float
    var popTwist: Float
    var popShadow: Float
    var popShadowReach: Float

    static let standard = PaperLook(
        backdrop: .linear(0xF4EDE2),
        seaDeep: .linear(0x1F6F7F),
        seaOpen: .linear(0x2A8291),
        seaShelf: .linear(0x3E99A5),
        seaShallow: .linear(0x68B6BC),
        seaCoast: .linear(0x9DD2CF),
        landCoast: .linear(0xEF7A56),
        landLow: .linear(0xF39064),
        landMid: .linear(0xF6A874),
        landHigh: .linear(0xF8C08A),
        landTop: .linear(0xFAD7A6),
        surf: .linear(0xFFFFFF),
        shade: .linear(0xC4C2D4),
        golden: .linear(0xFFE9CC),
        dusk: .linear(0xC99AB8),
        duskDeep: .linear(0x8373A1),
        night: .linear(0x45487D),
        cityLight: .linear(0xFFC266),
        pinhole: .linear(0xFFE2A8) * 4,
        pop: .linear(0xFFF8EC),
        seaSteps: SIMD4(-0.5, -1.8, -5, -12),
        landSteps: SIMD4(0.6, 1.8, 4, 8),
        contourWobble: 0.3,
        deckle: 0.1,
        grain: 0.08,
        grainCell: 0.8,
        shadowReach: 0.1,
        shadowLimit: 0.9,
        shadowSoftness: 0.08,
        shadowStrength: 0.45,
        occlusionWidth: 0.18,
        occlusionStrength: 0.35,
        edgeLight: 0.25,
        edgeWidth: 1.2,
        surfOffset: 0.1,
        surfWidth: 0.07,
        daylightFloor: 0.8,
        goldenWidth: 0.12,
        duskDepth: 0.24,
        duskSaturation: 0.9,
        nightSaturation: 0.15,
        nightLift: 0.25,
        crestWidth: 0.012,
        crestLight: 0.18,
        creaseLine: 0.3,
        foldShadow: 0.22,
        limbShade: 0.72,
        outline: 0.5,
        keyLight: 0.22,
        effectRelief: 3,
        pinholeSpacing: 0.45,
        pinholeSize: 0.26,
        pinholeThreshold: 0.08,
        pinholeGlow: 0.4,
        glow: 1.6,
        halo: 0.5,
        popHeight: Float(EffectTuning.paper.pop.height),
        popSize: 0.8,
        popPetals: 9,
        popTwist: 1.2,
        popShadow: 0.4,
        popShadowReach: 0.8
    )
}

extension SceneLook {
    static let paper = SceneLook(
        name: "Paper",
        backdrop: PaperLook.standard.backdrop.xyz,
        accent: Color(red: 0.8, green: 0.33, blue: 0.2),
        effects: .paper,
        sound: .paper,
        mesh: MeshLook(fragment: "paperFragment", background: "paperBackground", shape: .terraced, parameters: PaperLook.standard)
    )
}

extension EffectTuning {
    static let paper = EffectTuning(
        press: Press(
            dentDepth: 0.04,
            dentRadius: 0.13,
            dentShade: 8,
            frost: 0,
            cracks: 0,
            squash: 0.012,
            pressSpring: Spring(duration: 0.16, bounce: 0),
            releaseSpring: Spring(duration: 0.32, bounce: 0.25)
        ),
        pop: Pop(height: 0.015, radius: 0.07, glow: 0, spring: Spring(duration: 0.34, bounce: 0.45)),
        ripple: Ripple(tilt: 0, landShare: 0, flash: 0, displacement: 0, wavelength: 0.07, speed: 1.2, decay: 3.2, duration: 0),
        fling: Fling(stretchPerSpeed: 0.005, maximumStretch: 0.025, spring: Spring(duration: 0.26, bounce: 0.3)),
        flightArc: 0.5,
        inflate: Spring(duration: 0.7, bounce: 0.35),
        drag: .init(follow: Spring(duration: 0.1, bounce: 0), grainSharpness: 0.5)
    )
}

extension SoundTimbre {
    static let paper = SoundTimbre(id: "paper") { kind, voice in
        var voice = voice
        voice.noise = max(voice.noise, 0.4) * 3
        voice.decay *= 0.45
        voice.duration = min(voice.duration * 0.6, 0.18)
        voice.overtone *= 0.5
        voice.bell = 0
        voice.gain *= 0.85
        switch kind {
        case .press, .release, .carve:
            voice.startFrequency = 0
            voice.endFrequency = 0
            voice.hiss = 1.1
            voice.gain *= 3
        case .pop:
            voice.startFrequency *= 1.6
            voice.endFrequency *= 1.4
        case .inflate:
            voice.vibratoDepth = 0.06
            voice.vibratoRate = 38
            voice.vibratoDecay = 0.12
        default:
            break
        }
        return voice
    }
}
