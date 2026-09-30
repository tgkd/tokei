import SwiftUI

enum PixelSwatch {
    private static let cells = 13
    private static let bayer: [Double] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
    private static let night = Color(hex: 0x1A1C2C).opacity(0.78)
    private static let spark = Color(hex: 0xF4F4F4)
    private static let halo = Color(hex: 0x73EFF7)

    static func finish(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        let size = rect.width / CGFloat(cells)
        let lit = CGPoint(x: rect.midX - 22 * unit, y: rect.midY - 14 * unit)
        let reach = 58 * unit
        for row in 0..<cells {
            for column in 0..<cells {
                let cell = CGRect(x: rect.minX + CGFloat(column) * size, y: rect.minY + CGFloat(row) * size, width: size, height: size)
                let distance = hypot(cell.midX - lit.x, cell.midY - lit.y) / reach
                let threshold = (bayer[(row % 4) * 4 + column % 4] + 0.5) / 16
                if min(max((distance - 0.84) / 0.22, 0), 1) > threshold {
                    context.fill(Path(cell), with: .color(night))
                }
            }
        }
        let center = (column: 3, row: 3)
        for (dx, dy) in [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)] {
            let cell = CGRect(x: rect.minX + CGFloat(center.column + dx) * size, y: rect.minY + CGFloat(center.row + dy) * size, width: size, height: size)
            context.fill(Path(cell), with: .color(dx == 0 && dy == 0 ? spark : halo))
        }
    }

    static func pixelated(_ land: CGImage) -> CGImage? {
        guard
            let context = CGContext(data: nil, width: cells, height: cells, bitsPerComponent: 8, bytesPerRow: cells * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
            let data = context.data
        else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(land, in: CGRect(x: 0, y: 0, width: cells, height: cells))
        let bytes = data.bindMemory(to: UInt8.self, capacity: cells * cells * 4)
        for index in 0..<(cells * cells) {
            let value: UInt8 = bytes[index * 4 + 3] > 110 ? 255 : 0
            for channel in 0..<4 {
                bytes[index * 4 + channel] = value
            }
        }
        return context.makeImage()
    }

    static func rim(in context: GraphicsContext, rect: CGRect, unit: CGFloat, look: SwatchLook) {
        let size = rect.width / CGFloat(cells)
        let radius = rect.width / 2 + size * 0.62
        func inside(_ column: Int, _ row: Int) -> Bool {
            let x = rect.minX + (CGFloat(column) + 0.5) * size - rect.midX
            let y = rect.minY + (CGFloat(row) + 0.5) * size - rect.midY
            return x * x + y * y <= radius * radius
        }
        var ring = Path()
        for row in -1...cells {
            for column in -1...cells where inside(column, row) {
                let edge = !inside(column + 1, row) || !inside(column - 1, row) || !inside(column, row + 1) || !inside(column, row - 1)
                if edge {
                    ring.addRect(CGRect(x: rect.minX + CGFloat(column) * size, y: rect.minY + CGFloat(row) * size, width: size, height: size))
                }
            }
        }
        context.fill(ring, with: .color(look.rim))
    }
}
