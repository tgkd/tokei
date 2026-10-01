import CoreGraphics
import Foundation

enum NightMask {
    struct Grid: Hashable {
        let columns: Int
        let rows: Int
        let dithered: Bool

        static let smooth = Grid(columns: 256, rows: 128, dithered: false)
    }

    private static let dayEdge = sin(0.5 * Double.pi / 180)
    private static let nightEdge = sin(-12 * Double.pi / 180)
    private static let bayer: [Double] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

    static func image(for date: Date, centerLongitude: Double, grid: Grid) -> CGImage? {
        let width = grid.columns
        let height = grid.rows
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
                var night = t * t * (3 - 2 * t)
                if grid.dithered {
                    night = night > (bayer[(row % 4) * 4 + column % 4] + 0.5) / 16 ? 1 : 0
                }
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
            shouldInterpolate: !grid.dithered,
            intent: .defaultIntent
        )
    }
}
