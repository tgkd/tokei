import SwiftUI
import simd

struct SakuraLook {
    var backdrop: SIMD4<Float>
    var blush: SIMD4<Float>
    var haze: SIMD4<Float>
    var seaDeep: SIMD4<Float>
    var seaOpen: SIMD4<Float>
    var seaShallow: SIMD4<Float>
    var seaShore: SIMD4<Float>
    var seaNight: SIMD4<Float>
    var landCoast: SIMD4<Float>
    var landLow: SIMD4<Float>
    var landHigh: SIMD4<Float>
    var landCrest: SIMD4<Float>
    var paper: SIMD4<Float>
    var komon: SIMD4<Float>
    var landShade: SIMD4<Float>
    var landNight: SIMD4<Float>
    var petalLight: SIMD4<Float>
    var petalDeep: SIMD4<Float>
    var blossomEye: SIMD4<Float>
    var pollen: SIMD4<Float>
    var raft: SIMD4<Float>
    var dusk: SIMD4<Float>
    var glow: SIMD4<Float>
    var cityLight: SIMD4<Float>
    var glint: SIMD4<Float>
    var nightHaze: SIMD4<Float>
    var patternInk: SIMD4<Float>
    var wrap: Float
    var shallowWidth: Float
    var shoreWidth: Float
    var clumpScale: Float
    var clumpDepth: Float
    var paperShore: Float
    var paperGrain: Float
    var komonSize: Float
    var komonDensity: Float
    var raftSize: Float
    var raftWidth: Float
    var raftDensity: Float
    var transmission: Float
    var twilightWidth: Float
    var haziness: Float
    var glintPower: Float
    var glintStrength: Float
    var nightLift: Float
    var cityGlow: Float
    var sheen: Float
    var petalTranslucency: Float
    var mist: Float
    var drift: Float
    var driftSize: Float
    var patternSize: Float
    var patternStrength: Float
    var patternTurns: Float
    var grain: Float

    static let standard = SakuraLook(
        backdrop: .linear(0xEEF0F4),
        blush: .linear(0xF8E6EA),
        haze: .linear(0xECE6F1),
        seaDeep: .linear(0x172E57),
        seaOpen: .linear(0x1F4577),
        seaShallow: .linear(0x3570A6),
        seaShore: .linear(0x8DB8D8),
        seaNight: .linear(0x10173A),
        landCoast: .linear(0xEE9DB1),
        landLow: .linear(0xF2ACBC),
        landHigh: .linear(0xF7C7D2),
        landCrest: .linear(0xFCE3EA),
        paper: .linear(0xF9EDF0),
        komon: .linear(0xEDC6D1),
        landShade: .linear(0xCB8098),
        landNight: .linear(0x4F4B7C),
        petalLight: .linear(0xFFF8FA),
        petalDeep: .linear(0xF3A7BA),
        blossomEye: .linear(0xD6517A),
        pollen: .linear(0xF4C35A),
        raft: .linear(0xFBDCE4),
        dusk: .linear(0xF8B49C),
        glow: .linear(0xFF9FA6),
        cityLight: .linear(0xFFC98A),
        glint: .linear(0xFFF4E4),
        nightHaze: .linear(0x3C3F73),
        patternInk: .linear(0xDDB9C6),
        wrap: 0.42,
        shallowWidth: 1.6,
        shoreWidth: 0.35,
        clumpScale: 70,
        clumpDepth: 0.07,
        paperShore: 1.4,
        paperGrain: 0.06,
        komonSize: 1.5,
        komonDensity: 0.6,
        raftSize: 0.1,
        raftWidth: 1.4,
        raftDensity: 0.75,
        transmission: 0.38,
        twilightWidth: 0.17,
        haziness: 0.32,
        glintPower: 28,
        glintStrength: 0.05,
        nightLift: 0.18,
        cityGlow: 1.2,
        sheen: 0.18,
        petalTranslucency: 0.7,
        mist: 0.5,
        drift: 0,
        driftSize: 8,
        patternSize: 26,
        patternStrength: 0.45,
        patternTurns: 5,
        grain: 0.035
    )
}

extension SceneLook {
    static let sakura = SceneLook(
        name: "Sakura",
        backdrop: SakuraLook.standard.backdrop.xyz,
        accent: Color(red: 0.878, green: 0.314, blue: 0.227),
        effects: .sakura,
        sound: .sakura,
        mesh: MeshLook(
            fragment: "sakuraFragment",
            background: "sakuraBackground",
            petals: "sakuraPetal",
            shape: .puffy,
            parameters: SakuraLook.standard,
            surface: SurfaceObjectsLook(kind: .petalBed, vertex: "sakuraBedVertex", fragment: "sakuraBedPetal", coverage: true, cullsBack: false)
        ),
        petalDrift: PetalDriftLook(light: 0xFFF4F7, deep: 0xF2A3B7, rate: 1.6, speed: 38, lifetime: 14)
    )
}

extension EffectTuning {
    static let sakura = EffectTuning(
        press: Press(
            dentDepth: 0,
            dentRadius: 0.13,
            dentShade: 0,
            frost: 0,
            cracks: 0,
            squash: 0,
            pressSpring: Spring(duration: 0.2, bounce: 0),
            releaseSpring: Spring(duration: 0.5, bounce: 0.35)
        ),
        pop: Pop(height: 0.018, radius: 0.06, glow: 0, spring: Spring(duration: 0.45, bounce: 0.45)),
        ripple: Ripple(tilt: 0.5, landShare: 0, flash: 0, displacement: 0.002, wavelength: 0.05, speed: 0.6, decay: 2.2, duration: 1.4),
        fling: Fling(stretchPerSpeed: 0.004, maximumStretch: 0.02, spring: Spring(duration: 0.45, bounce: 0.3)),
        flightArc: 0.45,
        inflate: Spring(duration: 0.9, bounce: 0.3),
        drag: .init(follow: Spring(duration: 0.22, bounce: 0.2), grainSpacing: 16, grainSharpness: 0.3),
        petals: Petals(
            lifetime: 4.2,
            stagger: 1.2,
            size: 0.024,
            fall: 0.2,
            drag: 0.6,
            launch: 0.16,
            flutter: 0.04,
            spin: 2.6,
            lift: 0.03,
            shower: 150,
            showerDelay: 0.3,
            pop: 30,
            flingPerSpeed: 12,
            flingMaximum: 80,
            windPerSpeed: 0.09
        ),
        wind: Wind(
            press: Wind.Gust(radius: 1.3, push: 1.0),
            hop: Wind.Gust(radius: 0.045, push: 0.022),
            outline: 0.28,
            brush: Wind.Brush(
                width: 0.9,
                spacing: 0.3,
                ahead: 2,
                aheadLimit: 1.2,
                aside: 0.35,
                wobble: 0.4,
                swell: 0.3,
                wavelength: 2.5,
                ragged: 0.75,
                veer: 0.5,
                curl: 0.45,
                puff: 2.5
            ),
            jitter: 0.3,
            veer: 0.3,
            spin: .pi,
            lift: 0.3,
            shortest: 0.6,
            longest: 1.5,
            farthest: 0.12,
            ceiling: 1.06,
            stack: 48
        )
    )
}
