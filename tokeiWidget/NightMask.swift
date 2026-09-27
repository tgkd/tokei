import CoreGraphics
import Foundation

enum NightMask {
    static let width = 256
    static let height = 128

    private static let dayEdge = sin(0.5 * Double.pi / 180)
    private static let nightEdge = sin(-12 * Double.pi / 180)

    static func image(for date: Date, centerLongitude: Double) -> CGImage? {
        let sun = SolarPosition(date: date)
        let sinDeclination = sin(sun.declination)
        let cosDeclination = cos(sun.declination)

        let columns = (0..<width).map { column -> Double in
            let longitude = (centerLongitude - 180 + (Double(column) + 0.5) / Double(width) * 360) * .pi / 180
            return cos(longitude - sun.subsolarLongitude)
        }

        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            let latitude = (90 - (Double(row) + 0.5) / Double(height) * 180) * .pi / 180
            let a = sin(latitude) * sinDeclination
            let b = cos(latitude) * cosDeclination
            for column in 0..<width {
                let altitude = a + b * columns[column]
                let t = min(max((dayEdge - altitude) / (dayEdge - nightEdge), 0), 1)
                let night = t * t * (3 - 2 * t)
                pixels[(row * width + column) * 4 + 3] = UInt8((night * 255).rounded())
            }
        }

        guard
            let provider = CGDataProvider(data: Data(pixels) as CFData),
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}
