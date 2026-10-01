import CoreGraphics
import Foundation
import SwiftUI
import UIKit

struct PixelMap {
    let surface: CGImage
    let night: CGImage?

    static func make(
        at date: Date,
        centerLongitude: Double,
        width: CGFloat,
        pixelSize: CGFloat,
        ocean: Color.Resolved,
        land: Color.Resolved,
        coast: Color.Resolved?
    ) -> PixelMap? {
        let columns = max(Int((width / pixelSize).rounded()), 16)
        let grid = NightMask.Grid(columns: columns, rows: max(columns / 2, 8), dithered: true)
        let key = SurfaceCache.Key(grid: grid, centerLongitude: centerLongitude, ocean: ocean, land: land, coast: coast)
        guard let surface = SurfaceCache.shared.surface(for: key) else { return nil }
        return PixelMap(surface: surface, night: MaskCache.shared.mask(for: date, centerLongitude: centerLongitude, grid: grid))
    }
}

private final class SurfaceCache: @unchecked Sendable {
    static let shared = SurfaceCache()

    struct Key: Hashable {
        let grid: NightMask.Grid
        let centerLongitude: Double
        let ocean: Color.Resolved
        let land: Color.Resolved
        let coast: Color.Resolved?
    }

    private static let sourceWidth = 720
    private static let sourceHeight = 360

    private let lock = NSLock()
    private var last: (key: Key, image: CGImage)?
    private lazy var coverage: [UInt8]? = Self.loadCoverage()

    func surface(for key: Key) -> CGImage? {
        lock.withLock {
            if let last, last.key == key {
                return last.image
            }
            guard let coverage, let image = Self.render(key, coverage: coverage) else { return nil }
            last = (key, image)
            return image
        }
    }

    private static func render(_ key: Key, coverage: [UInt8]) -> CGImage? {
        let columns = key.grid.columns
        let rows = key.grid.rows
        var land = [Bool](repeating: false, count: columns * rows)
        for row in 0..<rows {
            for column in 0..<columns {
                var sum = 0
                for sy in 0..<3 {
                    let latitude = 90 - (Double(row) + (Double(sy) + 0.5) / 3) / Double(rows) * 180
                    let y = min(max(Int((90 - latitude) / 180 * Double(sourceHeight)), 0), sourceHeight - 1)
                    for sx in 0..<3 {
                        let longitude = key.centerLongitude - 180 + (Double(column) + (Double(sx) + 0.5) / 3) / Double(columns) * 360
                        let x = ((Int(((longitude + 180) / 360 * Double(sourceWidth)).rounded(.down)) % sourceWidth) + sourceWidth) % sourceWidth
                        sum += Int(coverage[y * sourceWidth + x])
                    }
                }
                land[row * columns + column] = Double(sum) / (9 * 255) > 0.45
            }
        }

        func isLand(_ column: Int, _ row: Int) -> Bool {
            guard row >= 0, row < rows else { return false }
            return land[row * columns + (column + columns) % columns]
        }

        let ocean = premultiplied(key.ocean)
        let ground = premultiplied(key.land)
        let shore = key.coast.map { composite(premultiplied($0), over: ocean) }
        var pixels = [UInt8](repeating: 0, count: columns * rows * 4)
        for row in 0..<rows {
            for column in 0..<columns {
                let color: [UInt8]
                if isLand(column, row) {
                    color = ground
                } else if let shore, isLand(column + 1, row) || isLand(column - 1, row) || isLand(column, row + 1) || isLand(column, row - 1) {
                    color = shore
                } else {
                    color = ocean
                }
                let index = (row * columns + column) * 4
                pixels.replaceSubrange(index..<index + 4, with: color)
            }
        }

        guard
            let provider = CGDataProvider(data: Data(pixels) as CFData),
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        return CGImage(
            width: columns,
            height: rows,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: columns * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private static func premultiplied(_ color: Color.Resolved) -> [UInt8] {
        let alpha = min(max(Double(color.opacity), 0), 1)
        return [color.red, color.green, color.blue].map { channel in
            UInt8((min(max(Double(channel), 0), 1) * alpha * 255).rounded())
        } + [UInt8((alpha * 255).rounded())]
    }

    private static func composite(_ top: [UInt8], over bottom: [UInt8]) -> [UInt8] {
        let cover = Double(top[3]) / 255
        return zip(top, bottom).map { upper, lower in
            UInt8(min(Double(upper) + Double(lower) * (1 - cover), 255).rounded())
        }
    }

    private static func loadCoverage() -> [UInt8]? {
        guard let image = UIImage(named: "MapLand")?.cgImage else { return nil }
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
}
