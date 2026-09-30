import SwiftUI
import simd

struct PixelLook {
    var backdrop: SIMD4<Float>
    var haze: SIMD4<Float>
    var starDim: SIMD4<Float>
    var star: SIMD4<Float>
    var starBright: SIMD4<Float>
    var halo: SIMD4<Float>
    var haloDeep: SIMD4<Float>
    var outline: SIMD4<Float>
    var seaDeep: SIMD4<Float>
    var seaOpen: SIMD4<Float>
    var seaShelf: SIMD4<Float>
    var seaShallow: SIMD4<Float>
    var foam: SIMD4<Float>
    var grassLight: SIMD4<Float>
    var grass: SIMD4<Float>
    var grassShade: SIMD4<Float>
    var forestShade: SIMD4<Float>
    var sand: SIMD4<Float>
    var sandShade: SIMD4<Float>
    var snow: SIMD4<Float>
    var snowShade: SIMD4<Float>
    var rock: SIMD4<Float>
    var rockShade: SIMD4<Float>
    var rockLight: SIMD4<Float>
    var duskLand: SIMD4<Float>
    var duskSea: SIMD4<Float>
    var nightLand: SIMD4<Float>
    var nightSea: SIMD4<Float>
    var nightCoast: SIMD4<Float>
    var cityDim: SIMD4<Float>
    var city: SIMD4<Float>
    var cityCore: SIMD4<Float>
    var sparkle: SIMD4<Float>
    var sparkleEdge: SIMD4<Float>
    var shallowWidth: Float
    var shelfWidth: Float
    var openWidth: Float
    var duskPixels: Float
    var lightHigh: Float
    var slopeShade: Float
    var ditherBand: Float
    var reliefShade: Float
    var cityCell: Float
    var cityThreshold: Float
    var cityBright: Float
    var sparkleCount: Float
    var sparkleReach: Float
    var starCells: Float
    var starChance: Float
    var waveCell: Float
    var waveChance: Float
    var forestLevel: Float
    var sandLevel: Float
    var snowLevel: Float
    var rockLevel: Float
    var peakLevel: Float
    var polarRockLevel: Float
    var polarPeakLevel: Float
    var snowLatitudeLow: Float
    var snowLatitudeHigh: Float
    var capLevel: Float
    var capRise: Float

    static let standard = PixelLook(
        backdrop: .ink(0x1A1C2C),
        haze: .ink(0x29366F),
        starDim: .ink(0x566C86),
        star: .ink(0x94B0C2),
        starBright: .ink(0xF4F4F4),
        halo: .ink(0x41A6F6),
        haloDeep: .ink(0x3B5DC9),
        outline: .ink(0x1A1C2C),
        seaDeep: .ink(0x29366F),
        seaOpen: .ink(0x3B5DC9),
        seaShelf: .ink(0x41A6F6),
        seaShallow: .ink(0x73EFF7),
        foam: .ink(0xF4F4F4),
        grassLight: .ink(0xA7F070),
        grass: .ink(0x38B764),
        grassShade: .ink(0x257179),
        forestShade: .ink(0x29366F),
        sand: .ink(0xFFCD75),
        sandShade: .ink(0xEF7D57),
        snow: .ink(0xF4F4F4),
        snowShade: .ink(0x94B0C2),
        rock: .ink(0x566C86),
        rockShade: .ink(0x333C57),
        rockLight: .ink(0x94B0C2),
        duskLand: .ink(0xB13E53),
        duskSea: .ink(0x5D275D),
        nightLand: .ink(0x333C57),
        nightSea: .ink(0x29366F),
        nightCoast: .ink(0x566C86),
        cityDim: .ink(0xEF7D57),
        city: .ink(0xFFCD75),
        cityCore: .ink(0xF4F4F4),
        sparkle: .ink(0xF4F4F4),
        sparkleEdge: .ink(0x1A1C2C),
        shallowWidth: 0.1,
        shelfWidth: 0.9,
        openWidth: 3.6,
        duskPixels: 2.5,
        lightHigh: 0.62,
        slopeShade: 0.05,
        ditherBand: 0.07,
        reliefShade: 1.4,
        cityCell: 1.1,
        cityThreshold: 0.2,
        cityBright: 0.75,
        sparkleCount: 6,
        sparkleReach: 0.2,
        starCells: 56,
        starChance: 0.32,
        waveCell: 6,
        waveChance: 0.55,
        forestLevel: 0.2,
        sandLevel: 0.34,
        snowLevel: 0.62,
        rockLevel: 0.58,
        peakLevel: 0.6,
        polarRockLevel: 0.26,
        polarPeakLevel: 0.2,
        snowLatitudeLow: 0.35,
        snowLatitudeHigh: 0.95,
        capLevel: 4.5,
        capRise: 0.07
    )
}

extension SIMD4 where Scalar == Float {
    static func ink(_ hex: UInt32) -> SIMD4<Float> {
        let color = SIMD3<Float>.linear(hex)
        let peak = Swift.min(color.max(), 0.97)
        let target = color * (peak / Swift.max(color.max(), 1e-6))
        guard peak >= 0.76 else {
            return SIMD4(target, 1)
        }
        let reach: Float = 0.24
        let source = reach * reach / (1 - peak) - reach + 0.76
        let blend = 1 - 1 / (0.15 * (source - peak) + 1)
        let scaled = (target - SIMD3(repeating: peak * blend)) / (1 - blend)
        return SIMD4(scaled * (source / peak), 1)
    }
}

extension SceneLook {
    static let pixel = SceneLook(
        name: "Pixel",
        backdrop: PixelLook.standard.backdrop.xyz,
        accent: Color(red: 1, green: 0.804, blue: 0.459),
        effects: .pixel,
        sound: .pixel,
        mesh: MeshLook(
            fragment: "pixelFragment",
            background: "pixelBackground",
            pixelSize: 4,
            shape: .stepped,
            parameters: PixelLook.standard
        )
    )
}

extension EffectTuning {
    static let pixel = EffectTuning(
        press: Press(
            dentDepth: 0.035,
            dentRadius: 0.1,
            dentShade: 22,
            frost: 0,
            cracks: 0,
            squash: 0.012,
            pressSpring: Spring(duration: 0.12, bounce: 0),
            releaseSpring: Spring(duration: 0.3, bounce: 0.4)
        ),
        pop: Pop(height: 0.02, radius: 0.06, glow: 0, spring: Spring(duration: 0.3, bounce: 0.5)),
        ripple: Ripple(tilt: 0, landShare: 0, flash: 0, displacement: 0, wavelength: 0.07, speed: 0.35, decay: 2, duration: 0.9),
        fling: Fling(stretchPerSpeed: 0.004, maximumStretch: 0.02, spring: Spring(duration: 0.22, bounce: 0.4)),
        flightArc: 0.5,
        inflate: Spring(duration: 0.6, bounce: 0.45),
        drag: .init(follow: Spring(duration: 0.1, bounce: 0), grainSpacing: 16, grainSharpness: 0.6)
    )
}
