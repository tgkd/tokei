import SwiftUI
import simd

struct GardenLook {
    var backdrop: SIMD4<Float>
    var backdropShade: SIMD4<Float>
    var backdropLight: SIMD4<Float>
    var seaDeep: SIMD4<Float>
    var seaOpen: SIMD4<Float>
    var seaShallow: SIMD4<Float>
    var seaNight: SIMD4<Float>
    var glint: SIMD4<Float>
    var lawnDeep: SIMD4<Float>
    var lawn: SIMD4<Float>
    var lawnLight: SIMD4<Float>
    var lawnSun: SIMD4<Float>
    var meadow: SIMD4<Float>
    var sage: SIMD4<Float>
    var hedge: SIMD4<Float>
    var treeDark: SIMD4<Float>
    var treeLight: SIMD4<Float>
    var bush: SIMD4<Float>
    var shore: SIMD4<Float>
    var bladeDeep: SIMD4<Float>
    var bladeTip: SIMD4<Float>
    var bladeCool: SIMD4<Float>
    var bladeStraw: SIMD4<Float>
    var clover: SIMD4<Float>
    var cloverMark: SIMD4<Float>
    var cloverBloom: SIMD4<Float>
    var leaf: SIMD4<Float>
    var white: SIMD4<Float>
    var butter: SIMD4<Float>
    var rose: SIMD4<Float>
    var poppy: SIMD4<Float>
    var violet: SIMD4<Float>
    var sky: SIMD4<Float>
    var coral: SIMD4<Float>
    var magenta: SIMD4<Float>
    var plum: SIMD4<Float>
    var cornflower: SIMD4<Float>
    var indigo: SIMD4<Float>
    var lavender: SIMD4<Float>
    var eye: SIMD4<Float>
    var eyeDark: SIMD4<Float>
    var moon: SIMD4<Float>
    var twilight: SIMD4<Float>
    var cityLight: SIMD4<Float>
    var wrap: Float
    var shallowWidth: Float
    var shoreWidth: Float
    var glintPower: Float
    var glintStrength: Float
    var lawnScale: Float
    var grassScale: Float
    var grassContrast: Float
    var plotSize: Float
    var plotWarp: Float
    var pathChance: Float
    var hedgeWidth: Float
    var stripeWidth: Float
    var stripeStrength: Float
    var treeCell: Float
    var treeChance: Float
    var bushCell: Float
    var bushChance: Float
    var groveLevel: Float
    var grassCell: Float
    var grassChance: Float
    var grassLean: Float
    var grassCurl: Float
    var patchCell: Float
    var cloverChance: Float
    var meadowChance: Float
    var clusterCell: Float
    var clusterChance: Float
    var bouquetCell: Float
    var bouquetChance: Float
    var bouquetSize: Float
    var bouquetDelay: Float
    var climateBias: Float
    var coastMargin: Float
    var grow: Float
    var hold: Float
    var hide: Float
    var stagger: Float
    var shadowLength: Float
    var shadowStrength: Float
    var moonStrength: Float
    var terminatorWidth: Float
    var twilightWidth: Float
    var cityGlow: Float
    var haze: Float
    var dappleCells: Float
    var dappleStrength: Float
    var grain: Float

    static let standard = GardenLook(
        backdrop: .linear(0xDDE7CF),
        backdropShade: .linear(0xC9D8B6),
        backdropLight: .linear(0xF3F6EA),
        seaDeep: .linear(0x1B5A9A),
        seaOpen: .linear(0x2A7BC0),
        seaShallow: .linear(0x55C2D6),
        seaNight: .linear(0x0A1830),
        glint: .linear(0xFFFBEF),
        lawnDeep: .linear(0x2F6E2A),
        lawn: .linear(0x4F9A36),
        lawnLight: .linear(0x86BE45),
        lawnSun: .linear(0xB8D468),
        meadow: .linear(0xA9C94F),
        sage: .linear(0x7FA36A),
        hedge: .linear(0x2C5E25),
        treeDark: .linear(0x245520),
        treeLight: .linear(0x6FAF42),
        bush: .linear(0x8CC452),
        shore: .linear(0xE3D6A2),
        bladeDeep: .linear(0x2E7A26),
        bladeTip: .linear(0xC4E672),
        bladeCool: .linear(0x4F9A6E),
        bladeStraw: .linear(0xD9CC7F),
        clover: .linear(0x3A8848),
        cloverMark: .linear(0xCDE6B2),
        cloverBloom: .linear(0xF8EAF0),
        leaf: .linear(0x3B8A33),
        white: .linear(0xFBF8F0),
        butter: .linear(0xFFD447),
        rose: .linear(0xF68FB2),
        poppy: .linear(0xE8413A),
        violet: .linear(0x9B7BE0),
        sky: .linear(0x6CB6F2),
        coral: .linear(0xFF8C5A),
        magenta: .linear(0xD9418C),
        plum: .linear(0x6C2C7C),
        cornflower: .linear(0x3F6DE2),
        indigo: .linear(0x2D3488),
        lavender: .linear(0xA898E8),
        eye: .linear(0xF6C431),
        eyeDark: .linear(0x4A2C1A),
        moon: .linear(0xA9BCE0),
        twilight: .linear(0xF2A86B),
        cityLight: .linear(0xFFD27A),
        wrap: 0.3,
        shallowWidth: 1.4,
        shoreWidth: 0.22,
        glintPower: 160,
        glintStrength: 0.6,
        lawnScale: 5,
        grassScale: 250,
        grassContrast: 0.12,
        plotSize: 5,
        plotWarp: 1.2,
        pathChance: 0.3,
        hedgeWidth: 0.07,
        stripeWidth: 0.35,
        stripeStrength: 0.06,
        treeCell: 1.6,
        treeChance: 0.7,
        bushCell: 0.9,
        bushChance: 0.45,
        groveLevel: 0.42,
        grassCell: 2.0,
        grassChance: 0.85,
        grassLean: 0.22,
        grassCurl: 0.5,
        patchCell: 9,
        cloverChance: 0.2,
        meadowChance: 0.22,
        clusterCell: 3.8,
        clusterChance: 0.8,
        bouquetCell: 6.5,
        bouquetChance: 1,
        bouquetSize: 0.38,
        bouquetDelay: 0.55,
        climateBias: 0.3,
        coastMargin: 0.5,
        grow: 0.7,
        hold: 5,
        hide: 1.2,
        stagger: 0.4,
        shadowLength: 0.25,
        shadowStrength: 0.35,
        moonStrength: 0.25,
        terminatorWidth: 0.05,
        twilightWidth: 0.2,
        cityGlow: 0.9,
        haze: 0.18,
        dappleCells: 6,
        dappleStrength: 0.12,
        grain: 0.03
    )

    var bloomTiming: BloomTiming {
        BloomTiming(grow: Double(grow), hold: Double(hold), hide: Double(hide), stagger: Double(stagger + bouquetDelay) + 0.2)
    }

    var bouquetReach: Double {
        Double(bouquetCell) * .pi / 180
    }
}

extension SceneLook {
    static let garden = SceneLook(
        name: "Garden",
        backdrop: GardenLook.standard.backdrop.xyz,
        accent: Color(red: 0.27, green: 0.56, blue: 0.22),
        effects: .garden,
        sound: .garden,
        mesh: MeshLook(
            fragment: "gardenFragment",
            background: "gardenBackground",
            shape: .puffy,
            parameters: GardenLook.standard,
            blooms: BloomSettings(
                timing: GardenLook.standard.bloomTiming,
                width: 1.1,
                tuft: 1,
                pop: GardenLook.standard.bouquetReach * 0.85,
                minimumWidth: GardenLook.standard.bouquetReach * 0.5,
                minimumTuft: GardenLook.standard.bouquetReach * 0.85
            )
        )
    )
}

extension EffectTuning {
    static let garden = EffectTuning(
        press: Press(
            dentDepth: 0.015,
            dentRadius: 0.1,
            dentShade: 2,
            frost: 0,
            cracks: 0,
            squash: 0.006,
            pressSpring: Spring(duration: 0.2, bounce: 0),
            releaseSpring: Spring(duration: 0.45, bounce: 0.2)
        ),
        pop: Pop(height: 0.01, radius: 0.045, glow: 0, spring: Spring(duration: 0.5, bounce: 0.25)),
        ripple: Ripple(tilt: 0.6, landShare: 0, flash: 0, displacement: 0, wavelength: 0.03, speed: 0.35, decay: 1.5, duration: 1.6),
        fling: Fling(stretchPerSpeed: 0.002, maximumStretch: 0.008, spring: Spring(duration: 0.4, bounce: 0.05)),
        flightArc: 0.4,
        inflate: Spring(duration: 1.6, bounce: 0.1),
        drag: .init(follow: Spring(duration: 0.18, bounce: 0), grainSpacing: 10, grainSharpness: 0.4)
    )
}
