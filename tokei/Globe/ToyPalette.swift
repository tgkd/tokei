import Metal
import SwiftUI
import simd

struct ToyPalette {
    var backdrop: SIMD4<Float>
    var ocean: SIMD4<Float>
    var oceanNight: SIMD4<Float>
    var landLow: SIMD4<Float>
    var landHigh: SIMD4<Float>
    var landNight: SIMD4<Float>
    var cityLight: SIMD4<Float>
    var twilight: SIMD4<Float>
    var rim: SIMD4<Float>
    var snow: SIMD4<Float>

    static let standard = ToyPalette(
        backdrop: .linear(0x15112A),
        ocean: .linear(0x4B4FC7),
        oceanNight: .linear(0x151547),
        landLow: .linear(0xFF9166),
        landHigh: .linear(0xFFC08F),
        landNight: .linear(0x45255A),
        cityLight: .linear(0xFFD27A),
        twilight: .linear(0xFF6A3D),
        rim: .linear(0x7F8CFF),
        snow: .linear(0xFFF4EA)
    )

    static let ice = ToyPalette(
        backdrop: .linear(0x0A0D12),
        ocean: .linear(0x1F2B3A),
        oceanNight: .linear(0x0A0F16),
        landLow: .linear(0x7F93A8),
        landHigh: .linear(0xC0CEDB),
        landNight: .linear(0x1B2430),
        cityLight: .linear(0xBFD8F2),
        twilight: .linear(0x5C7899),
        rim: .linear(0x7FA3C8),
        snow: .linear(0xDCE6F0)
    )

    var backdropColor: Color {
        Color(.sRGBLinear, red: Double(backdrop.x), green: Double(backdrop.y), blue: Double(backdrop.z))
    }

    var clearColor: MTLClearColor {
        MTLClearColor(red: Self.encoded(backdrop.x), green: Self.encoded(backdrop.y), blue: Self.encoded(backdrop.z), alpha: 1)
    }

    private static func encoded(_ linear: Float) -> Double {
        let clamped = Double(min(max(linear, 0), 1))
        if clamped <= 0.0031308 {
            return clamped * 12.92
        }
        return 1.055 * pow(clamped, 1 / 2.4) - 0.055
    }
}

struct ToyMaterial {
    var sparkle: Float
    var sparkleDensity: Float
    var sparkleSharpness: Float
    var sparkleScatter: Float
    var plateTilt: Float
    var plateScale: Float
    var seams: Float
    var snowCover: Float
    var snowRecovery: Float
    var snowDepth: Float
    var snowRim: Float
    var reserved: Float = 0

    static let standard = ToyMaterial(
        sparkle: 0,
        sparkleDensity: 1,
        sparkleSharpness: 1,
        sparkleScatter: 0,
        plateTilt: 0,
        plateScale: 1,
        seams: 0,
        snowCover: 0,
        snowRecovery: 1,
        snowDepth: 0,
        snowRim: 0
    )

    static let ice = ToyMaterial(
        sparkle: 2.5,
        sparkleDensity: 1,
        sparkleSharpness: 60,
        sparkleScatter: 0.8,
        plateTilt: 0.08,
        plateScale: 1,
        seams: 0.25,
        snowCover: 1,
        snowRecovery: 5,
        snowDepth: 0.012,
        snowRim: 0.35
    )
}

private extension SIMD4 where Scalar == Float {
    static func linear(_ hex: UInt32) -> SIMD4<Float> {
        func channel(_ shift: UInt32) -> Float {
            let encoded = Float((hex >> shift) & 0xFF) / 255
            if encoded <= 0.04045 {
                return encoded / 12.92
            }
            return pow((encoded + 0.055) / 1.055, 2.4)
        }
        return SIMD4(channel(16), channel(8), channel(0), 1)
    }
}
