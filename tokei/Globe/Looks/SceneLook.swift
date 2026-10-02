import Metal
import SwiftUI
import simd

struct SceneLook {
    let name: String
    let backdrop: SIMD3<Float>
    let accent: Color
    let effects: EffectTuning
    let sound: SoundTimbre?
    let mesh: MeshLook?
    var petalDrift: PetalDriftLook?
    var popEcho: SoundSequence? = nil
    var strikes: StrikeSchedule? = nil

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

struct PetalDriftLook {
    let light: UInt32
    let deep: UInt32
    let rate: Float
    let speed: CGFloat
    let lifetime: Float
}

struct StrikeSchedule: Sendable {
    let sequence: @Sendable (_ hour: Int, _ minute: Int) -> SoundSequence
    let duration: @Sendable (_ hour: Int, _ minute: Int) -> Double
}

struct MeshLook {
    let fragment: String
    let background: String?
    let clouds: String?
    let petals: String?
    let pixelSize: Double?
    let shape: ToyShape
    let parameters: [UInt8]
    let snow: SnowSettings?
    let marks: MarkSettings?
    let blooms: BloomSettings?
    let surface: SurfaceObjectsLook?
    let chipLift: Double

    init<Parameters>(
        fragment: String,
        background: String? = nil,
        clouds: String? = nil,
        petals: String? = nil,
        pixelSize: Double? = nil,
        shape: ToyShape,
        parameters: Parameters,
        snow: SnowSettings? = nil,
        marks: MarkSettings? = nil,
        blooms: BloomSettings? = nil,
        surface: SurfaceObjectsLook? = nil,
        chipLift: Double = 0
    ) {
        self.fragment = fragment
        self.background = background
        self.clouds = clouds
        self.petals = petals
        self.pixelSize = pixelSize
        self.shape = shape
        self.parameters = withUnsafeBytes(of: parameters) { Array($0) }
        self.snow = snow
        self.marks = marks
        self.blooms = blooms
        self.surface = surface
        self.chipLift = chipLift
    }
}

struct SnowSettings {
    let recovery: Double
    var footprints = true
}

extension SIMD4 where Scalar == Float {
    static func linear(_ hex: UInt32) -> SIMD4<Float> {
        SIMD4(SIMD3.linear(hex), 1)
    }

    var xyz: SIMD3<Float> {
        SIMD3(x, y, z)
    }
}

extension SIMD3 where Scalar == Float {
    static func linear(_ hex: UInt32) -> SIMD3<Float> {
        SIMD3(decoded(Float((hex >> 16) & 0xFF) / 255), decoded(Float((hex >> 8) & 0xFF) / 255), decoded(Float(hex & 0xFF) / 255))
    }

    static func linear(red: Float, green: Float, blue: Float) -> SIMD3<Float> {
        SIMD3(decoded(red), decoded(green), decoded(blue))
    }

    private static func decoded(_ encoded: Float) -> Float {
        if encoded <= 0.04045 {
            return encoded / 12.92
        }
        return pow((encoded + 0.055) / 1.055, 2.4)
    }
}
