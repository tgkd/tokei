import Accelerate
import Foundation

struct ReliefMap {
    private static let peakMeters: Float = 6400
    private static let slopeRange: Float = 0.1
    private static let earthRadiusMeters: Float = 6_371_000
    private static let smoothing: [Float] = [1, 4, 6, 4, 1].map { $0 / 16 }

    let texels: [Int8]

    init(elevation: [UInt8], width: Int, height: Int) {
        let heights = Self.smoothed(elevation.map { Float($0) / 255 }, width: width, height: height)
        let rise = Self.peakMeters / Self.earthRadiusMeters / Self.slopeRange
        let longitudeStep = 2 * Float.pi / Float(width)
        let latitudeStep = Float.pi / Float(height)
        var texels = [Int8](repeating: 0, count: width * height * 2)
        texels.withUnsafeMutableBufferPointer { output in
            heights.withUnsafeBufferPointer { input in
                DispatchQueue.concurrentPerform(iterations: height) { row in
                    let latitude = (0.5 - (Float(row) + 0.5) / Float(height)) * .pi
                    let eastRun = 2 * max(cos(latitude), 0.05) * longitudeStep
                    let north = max(row - 1, 0)
                    let south = min(row + 1, height - 1)
                    let northRun = Float(south - north) * latitudeStep
                    for column in 0..<width {
                        let west = column == 0 ? width - 1 : column - 1
                        let east = column == width - 1 ? 0 : column + 1
                        let here = row * width + column
                        let slopeEast = (input[row * width + east] - input[row * width + west]) * rise / eastRun
                        let slopeNorth = (input[north * width + column] - input[south * width + column]) * rise / northRun
                        output[here * 2] = Self.snorm(slopeEast)
                        output[here * 2 + 1] = Self.snorm(slopeNorth)
                    }
                }
            }
        }
        self.texels = texels
    }

    private static func snorm(_ value: Float) -> Int8 {
        Int8((min(max(value, -1), 1) * 127).rounded())
    }

    private static func smoothed(_ values: [Float], width: Int, height: Int) -> [Float] {
        let radius = smoothing.count / 2
        let paddedWidth = width + 2 * radius
        var padded = [Float](repeating: 0, count: paddedWidth * height)
        for row in 0..<height {
            let source = row * width
            let target = row * paddedWidth
            for column in 0..<paddedWidth {
                padded[target + column] = values[source + (column - radius + width) % width]
            }
        }
        var result = [Float](repeating: 0, count: width * height)
        padded.withUnsafeMutableBufferPointer { source in
            result.withUnsafeMutableBufferPointer { target in
                var input = vImage_Buffer(data: source.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(paddedWidth), rowBytes: paddedWidth * MemoryLayout<Float>.stride)
                var output = vImage_Buffer(data: target.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * MemoryLayout<Float>.stride)
                _ = vImageSepConvolve_PlanarF(&input, &output, nil, vImagePixelCount(radius), 0, smoothing, UInt32(smoothing.count), smoothing, UInt32(smoothing.count), 0, 0, vImage_Flags(kvImageEdgeExtend))
            }
        }
        return result
    }
}
