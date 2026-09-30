import Accelerate
import CoreGraphics
import Foundation
import ImageIO
import Metal
import simd

struct ToyTerrain {
    struct Shape {
        let surface: ToySurface
        let relief: TerrainGrid
    }

    static let plateHeight = 0.02

    let coast: TerrainGrid
    let tree: TerrainTree
    let field: TerrainField

    init?(waterMaskURL: URL, elevationURL: URL?, device: MTLDevice) {
        guard let water = Self.decodeGray(url: waterMaskURL) else { return nil }
        let width = water.width
        let height = water.height
        let degree = Double(width) / 360
        let blurred = Self.blur(water.land, width: width, height: height, sigma: 0.5 * degree)
        let distance = CoastDistance.signedDegrees(coverage: blurred, threshold: 0.45, width: width, height: height)
        guard let coast = TerrainGrid(distance, width: width, height: height, device: device) else { return nil }
        self.coast = coast
        tree = TerrainTree(coast: coast, depth: ToySurface.deepestLevel)
        field = TerrainField(
            width: width / 2,
            height: height / 2,
            degree: degree / 2,
            coverage: Self.halve(Self.smoothstep(0.35, 0.55, blurred), width: width, height: height),
            distance: Self.halve(distance, width: width, height: height),
            elevationURL: elevationURL
        )
    }

    func shape(_ shape: ToyShape, device: MTLDevice) -> Shape? {
        let lift = shape.lift(field)
        guard
            lift.heights.count == field.width * field.height,
            lift.relief.count == field.width * field.height,
            let heights = TerrainGrid(lift.heights, width: field.width, height: field.height, device: device),
            let relief = TerrainGrid(Self.halve(lift.relief, width: field.width, height: field.height), width: field.width / 2, height: field.height / 2, device: device)
        else { return nil }
        let surface = ToySurface(coast: coast, lift: heights, liftHeights: lift.heights, profile: lift.profile, tree: tree)
        return Shape(surface: surface, relief: relief)
    }

    static func direction(column: Int, row: Int, width: Int, height: Int) -> SIMD3<Double> {
        let latitude = (0.5 - (Double(row) + 0.5) / Double(height)) * .pi
        let longitude = ((Double(column) + 0.5) / Double(width) - 0.5) * 2 * .pi
        return SIMD3(cos(latitude) * sin(longitude), sin(latitude), cos(latitude) * cos(longitude))
    }

    static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    static func smoothstep(_ edge0: Float, _ edge1: Float, _ values: [Float]) -> [Float] {
        var ramp = [Float](repeating: 0, count: values.count)
        var result = [Float](repeating: 0, count: values.count)
        var scale = 1 / (edge1 - edge0)
        var offset = -edge0 / (edge1 - edge0)
        var low: Float = 0
        var high: Float = 1
        var slope: Float = -2
        var base: Float = 3
        let count = vDSP_Length(values.count)
        ramp.withUnsafeMutableBufferPointer { ramp in
            result.withUnsafeMutableBufferPointer { result in
                let t = ramp.baseAddress!
                let r = result.baseAddress!
                vDSP_vsmsa(values, 1, &scale, &offset, t, 1, count)
                vDSP_vclip(t, 1, &low, &high, t, 1, count)
                vDSP_vsmsa(t, 1, &slope, &base, r, 1, count)
                vDSP_vmul(r, 1, t, 1, r, 1, count)
                vDSP_vmul(r, 1, t, 1, r, 1, count)
            }
        }
        return result
    }

    static func blur(_ values: [Float], width: Int, height: Int, sigma: Double) -> [Float] {
        let radius = max(Int((sigma * 3).rounded(.up)), 1)
        let weights = (-radius...radius).map { Float(exp(-Double($0 * $0) / (2 * sigma * sigma))) }
        let total = weights.reduce(0, +)
        let kernel = weights.map { $0 / total }
        let paddedWidth = width + 2 * radius
        var padded = [Float](repeating: 0, count: paddedWidth * height)
        values.withUnsafeBufferPointer { source in
            padded.withUnsafeMutableBufferPointer { target in
                var row = 0
                while row < height {
                    let input = source.baseAddress! + row * width
                    let output = target.baseAddress! + row * paddedWidth
                    output.update(from: input + width - radius, count: radius)
                    (output + radius).update(from: input, count: width)
                    (output + radius + width).update(from: input, count: radius)
                    row += 1
                }
            }
        }
        var result = [Float](repeating: 0, count: width * height)
        padded.withUnsafeMutableBufferPointer { source in
            result.withUnsafeMutableBufferPointer { target in
                var input = vImage_Buffer(data: source.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(paddedWidth), rowBytes: paddedWidth * MemoryLayout<Float>.stride)
                var output = vImage_Buffer(data: target.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: width * MemoryLayout<Float>.stride)
                _ = vImageSepConvolve_PlanarF(&input, &output, nil, vImagePixelCount(radius), 0, kernel, UInt32(kernel.count), kernel, UInt32(kernel.count), 0, 0, vImage_Flags(kvImageEdgeExtend))
            }
        }
        return result
    }

    private static func halve(_ values: [Float], width: Int, height: Int) -> [Float] {
        let halfWidth = width / 2
        let halfHeight = height / 2
        var result = [Float](repeating: 0, count: halfWidth * halfHeight)
        values.withUnsafeBufferPointer { values in
            result.withUnsafeMutableBufferPointer { result in
                let source = values.baseAddress!
                let target = result.baseAddress!
                var y = 0
                while y < halfHeight {
                    var x = 0
                    while x < halfWidth {
                        let top = (2 * y) * width + 2 * x
                        let bottom = top + width
                        target[y * halfWidth + x] = (source[top] + source[top + 1] + source[bottom] + source[bottom + 1]) / 4
                        x += 1
                    }
                    y += 1
                }
            }
        }
        return result
    }

    static func decodeElevation(url: URL, width: Int, height: Int) -> [Float]? {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
            image.width >= width,
            image.height >= height
        else { return nil }
        let sourceWidth = image.width
        let sourceHeight = image.height
        var pixels = [UInt8](repeating: 0, count: sourceWidth * sourceHeight)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: sourceWidth,
                    height: sourceHeight,
                    bitsPerComponent: 8,
                    bytesPerRow: sourceWidth,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                )
            else { return false }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: sourceWidth, height: sourceHeight))
            return true
        }
        guard drawn else { return nil }
        var elevation = [Float](repeating: 0, count: width * height)
        pixels.withUnsafeBufferPointer { pixels in
            var row = 0
            while row < height {
                let top = row * sourceHeight / height
                let bottom = max((row + 1) * sourceHeight / height, top + 1)
                var column = 0
                while column < width {
                    let left = column * sourceWidth / width
                    let right = max((column + 1) * sourceWidth / width, left + 1)
                    var peak: UInt8 = 0
                    var y = top
                    while y < bottom {
                        var x = left
                        while x < right {
                            peak = max(peak, pixels[y * sourceWidth + x])
                            x += 1
                        }
                        y += 1
                    }
                    elevation[row * width + column] = Float(peak) / 255
                    column += 1
                }
                row += 1
            }
        }
        return elevation
    }

    private static func decodeGray(url: URL) -> (land: [Float], width: Int, height: Int)? {
        guard
            let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        let width = image.width
        let height = image.height
        let colorSpace = image.colorSpace?.model == .monochrome ? image.colorSpace : CGColorSpaceCreateDeviceGray()
        var pixels = [UInt8](repeating: 0, count: width * height)
        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard
                let colorSpace,
                let context = CGContext(
                    data: buffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                )
            else { return false }
            context.interpolationQuality = .none
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        var land = [Float](repeating: 0, count: width * height)
        var scale: Float = -1 / 255
        var one: Float = 1
        land.withUnsafeMutableBufferPointer { land in
            let values = land.baseAddress!
            vDSP_vfltu8(pixels, 1, values, 1, vDSP_Length(land.count))
            vDSP_vsmsa(values, 1, &scale, &one, values, 1, vDSP_Length(land.count))
        }
        return (land, width, height)
    }
}
