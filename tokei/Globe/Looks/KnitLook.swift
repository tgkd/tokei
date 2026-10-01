import SwiftUI
import simd

struct KnitLook {
    var backdrop: SIMD4<Float>
    var feltShade: SIMD4<Float>
    var fiber: SIMD4<Float>
    var indigo: SIMD4<Float>
    var indigoDeep: SIMD4<Float>
    var oatmeal: SIMD4<Float>
    var cream: SIMD4<Float>
    var rust: SIMD4<Float>
    var mustard: SIMD4<Float>
    var forest: SIMD4<Float>
    var floss: SIMD4<Float>
    var nightTint: SIMD4<Float>
    var knot: SIMD4<Float>
    var sheen: SIMD4<Float>
    var twilight: SIMD4<Float>
    var wood: SIMD4<Float>
    var rowHeight: Float
    var stitchWidth: Float
    var sectors: Float
    var legWidth: Float
    var legTilt: Float
    var plyFrequency: Float
    var plyContrast: Float
    var fuzzScale: Float
    var fuzzStrength: Float
    var sheenRoughness: Float
    var sheenStrength: Float
    var motifBand: Float
    var knotCell: Float
    var knotRadius: Float
    var knotGlow: Float
    var stretch: Float
    var pressDepth: Float
    var pucker: Float
    var buttonRadius: Float
    var buttonHeight: Float
    var patternSize: Float
    var patternTurns: Float
    var patternStrength: Float
    var terminatorWidth: Float
    var wrap: Float
    var reserved1: Float = 0
    var reserved2: Float = 0
    var reserved3: Float = 0

    static let standard = KnitLook(
        backdrop: .linear(0x8E4632),
        feltShade: .linear(0x6E3424),
        fiber: .linear(0xE9DFC9),
        indigo: .linear(0x34507A),
        indigoDeep: .linear(0x223652),
        oatmeal: .linear(0xE8DCC4),
        cream: .linear(0xF4EEE2),
        rust: .linear(0xB5523B),
        mustard: .linear(0xD7A12F),
        forest: .linear(0x3F6B4A),
        floss: .linear(0xC43A2F),
        nightTint: .linear(0x2B3352),
        knot: .linear(0xE2B13C),
        sheen: .linear(0xFFF4E0),
        twilight: .linear(0xE8A070),
        wood: .linear(0x8A5A3B),
        rowHeight: 2.6,
        stitchWidth: 2.6,
        sectors: 8,
        legWidth: 0.32,
        legTilt: 0.55,
        plyFrequency: 9,
        plyContrast: 0.08,
        fuzzScale: 0.4,
        fuzzStrength: 0.15,
        sheenRoughness: 0.35,
        sheenStrength: 0.35,
        motifBand: 7,
        knotCell: 0.9,
        knotRadius: 0.3,
        knotGlow: 0.4,
        stretch: 1.6,
        pressDepth: 0.11,
        pucker: 0.6,
        buttonRadius: 0.035,
        buttonHeight: 0.025,
        patternSize: 16,
        patternTurns: 6,
        patternStrength: 0.85,
        terminatorWidth: 0.03,
        wrap: 0.35
    )
}

extension SceneLook {
    static let knit = SceneLook(
        name: "Knit",
        backdrop: KnitLook.standard.backdrop.xyz,
        accent: Color(red: 0.89, green: 0.69, blue: 0.24),
        effects: .knit,
        sound: .knit,
        mesh: MeshLook(
            fragment: "knitFragment",
            background: "knitBackground",
            shape: .puffy,
            parameters: KnitLook.standard,
            marks: MarkSettings(drag: .stitches(dash: 4, gap: 2.6), pop: nil, width: 0.1)
        )
    )
}

extension EffectTuning {
    static let knit = EffectTuning(
        press: Press(
            dentDepth: 0.11,
            dentRadius: 0.2,
            dentShade: 4,
            frost: 0,
            cracks: 0,
            squash: 0.03,
            pressSpring: Spring(duration: 0.3, bounce: 0),
            releaseSpring: Spring(duration: 0.55, bounce: 0.1),
            followHaptic: true
        ),
        pop: Pop(height: 0.025, radius: 0.05, glow: 0, spring: Spring(duration: 0.55, bounce: 0.35)),
        ripple: Ripple(tilt: 0, landShare: 0, flash: 0, displacement: 0, wavelength: 0.08, speed: 1, decay: 3, duration: 0),
        fling: Fling(stretchPerSpeed: 0.012, maximumStretch: 0.06, spring: Spring(duration: 0.7, bounce: 0.2)),
        flightArc: 0.55,
        inflate: Spring(duration: 1.0, bounce: 0.3),
        drag: .init(follow: Spring(duration: 0.24, bounce: 0.1), grainSpacing: 10, grainSharpness: 0.4)
    )
}
