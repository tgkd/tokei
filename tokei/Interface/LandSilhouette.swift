import CoreGraphics
import Foundation
import ImageIO

enum LandSilhouette {
    static let diameter = 300
    private static let sourceWidth = 720
    private static let sourceHeight = 360

    static func render(latitude: Double, longitude: Double) -> CGImage? {
        guard
            let url = Bundle.main.url(forResource: "earth-water", withExtension: "png"),
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let mask = CGImageSourceCreateImageAtIndex(source, 0, nil),
            let water = downsampled(mask)
        else {
            return nil
        }
        let side = diameter
        let radius = Double(side) / 2
        let centerLatitude = latitude * .pi / 180
        let centerLongitude = longitude * .pi / 180
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        for row in 0..<side {
            let y = (radius - Double(row) - 0.5) / radius
            for column in 0..<side {
                let x = (Double(column) + 0.5 - radius) / radius
                let planar = x * x + y * y
                guard planar < 1 else { continue }
                let z = (1 - planar).squareRoot()
                let pointLatitude = asin(z * sin(centerLatitude) + y * cos(centerLatitude))
                let pointLongitude = centerLongitude + atan2(x, z * cos(centerLatitude) - y * sin(centerLatitude))
                let coverage = 1 - sample(water, latitude: pointLatitude, longitude: pointLongitude)
                let land = UInt8(max(0, min(255, coverage * 255)))
                let index = (row * side + column) * 4
                pixels[index] = land
                pixels[index + 1] = land
                pixels[index + 2] = land
                pixels[index + 3] = land
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(
            width: side,
            height: side,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    private static func downsampled(_ image: CGImage) -> [UInt8]? {
        var buffer = [UInt8](repeating: 0, count: sourceWidth * sourceHeight)
        let drawn = buffer.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: sourceWidth,
                height: sourceHeight,
                bitsPerComponent: 8,
                bytesPerRow: sourceWidth,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue
            ) else {
                return false
            }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: sourceWidth, height: sourceHeight))
            return true
        }
        return drawn ? buffer : nil
    }

    private static func sample(_ water: [UInt8], latitude: Double, longitude: Double) -> Double {
        let u = (longitude / (2 * .pi) + 0.5) * Double(sourceWidth) - 0.5
        let v = (0.5 - latitude / .pi) * Double(sourceHeight) - 0.5
        let x0 = Int(u.rounded(.down))
        let y0 = Int(v.rounded(.down))
        let fx = u - Double(x0)
        let fy = v - Double(y0)
        func value(_ x: Int, _ y: Int) -> Double {
            let wrapped = ((x % sourceWidth) + sourceWidth) % sourceWidth
            let clamped = min(max(y, 0), sourceHeight - 1)
            return Double(water[clamped * sourceWidth + wrapped]) / 255
        }
        let top = value(x0, y0) * (1 - fx) + value(x0 + 1, y0) * fx
        let bottom = value(x0, y0 + 1) * (1 - fx) + value(x0 + 1, y0 + 1) * fx
        return top * (1 - fy) + bottom * fy
    }
}
