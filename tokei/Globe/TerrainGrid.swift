import Accelerate
import Foundation
import Metal
import simd

struct TerrainGrid {
    let buffer: MTLBuffer
    let width: Int
    let height: Int
    private let values: UnsafePointer<Float16>

    init?(_ values: [Float], width: Int, height: Int, device: MTLDevice) {
        guard let buffer = device.makeBuffer(length: width * height * MemoryLayout<Float16>.stride, options: .storageModeShared) else { return nil }
        values.withUnsafeBufferPointer { source in
            var input = vImage_Buffer(data: UnsafeMutableRawPointer(mutating: source.baseAddress), height: 1, width: vImagePixelCount(width * height), rowBytes: width * height * MemoryLayout<Float>.stride)
            var output = vImage_Buffer(data: buffer.contents(), height: 1, width: vImagePixelCount(width * height), rowBytes: width * height * MemoryLayout<Float16>.stride)
            _ = vImageConvert_PlanarFtoPlanar16F(&input, &output, vImage_Flags(kvImageNoFlags))
        }
        self.buffer = buffer
        self.width = width
        self.height = height
        self.values = UnsafePointer(buffer.contents().assumingMemoryBound(to: Float16.self))
    }

    func sample(_ direction: SIMD3<Double>) -> Double {
        let longitude = atan2(direction.x, direction.z)
        let latitude = asin(min(max(direction.y, -1), 1))
        let x = (longitude / (2 * .pi) + 0.5) * Double(width) - 0.5
        let y = (0.5 - latitude / .pi) * Double(height) - 0.5
        let left = floor(x)
        let top = floor(y)
        let fx = x - left
        let fy = y - top
        let column = Int(left)
        let row = Int(top)
        let upper = value(column, row) * (1 - fx) + value(column + 1, row) * fx
        let lower = value(column, row + 1) * (1 - fx) + value(column + 1, row + 1) * fx
        return upper * (1 - fy) + lower * fy
    }

    private func value(_ column: Int, _ row: Int) -> Double {
        let wrapped = ((column % width) + width) % width
        let clamped = row < 0 ? 0 : (row >= height ? height - 1 : row)
        return Double(values[clamped * width + wrapped])
    }
}
