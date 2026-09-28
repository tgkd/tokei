import Accelerate
import CoreGraphics
import Foundation
import ImageIO
import simd

struct ToyVertex {
    var position: SIMD4<Float>
}

enum ToyShape: CaseIterable {
    case puffy
    case glacier

    var mountains: [MountainRange] {
        switch self {
        case .puffy: []
        case .glacier: MountainRange.iconic
        }
    }

    fileprivate func terrain(from coastline: [Float], width: Int, height: Int, degree: Double) -> (heights: [Float], relief: [Float]) {
        let peak = Float(ToyTerrain.plateHeight)
        switch self {
        case .puffy:
            let shore = ToyTerrain.blur(coastline, width: width, height: height, sigma: 0.6 * degree)
            let puff = ToyTerrain.blur(coastline, width: width, height: height, sigma: 2 * degree)
            let heights = zip(shore, puff).map { shore, puff in
                peak * (0.45 * ToyTerrain.smoothstep(0.5, 1, shore) + 0.55 * ToyTerrain.smoothstep(0.5, 1, puff))
            }
            return (heights, heights.map { $0 / peak })
        case .glacier:
            let edge = ToyTerrain.blur(coastline, width: width, height: height, sigma: 0.25 * degree)
            let tier = ToyTerrain.blur(coastline, width: width, height: height, sigma: 3 * degree)
            let land = ToyTerrain.blur(coastline, width: width, height: height, sigma: 0.8 * degree)
            let ranges = mountains.map { $0.carve() }
            var heights = [Float](repeating: 0, count: width * height)
            var relief = [Float](repeating: 0, count: width * height)
            for row in 0..<height {
                for column in 0..<width {
                    let index = row * width + column
                    let shelf = peak * (0.6 * ToyTerrain.smoothstep(0.5, 0.62, edge[index]) + 0.4 * ToyTerrain.smoothstep(0.55, 0.62, tier[index]))
                    let direction = ToyTerrain.direction(column: column, row: row, width: width, height: height)
                    var rise = 0.0
                    var summit = 0.0
                    for range in ranges {
                        let height = range.height(at: direction)
                        rise = max(rise, height)
                        summit = max(summit, height / range.tallest)
                    }
                    let onLand = Double(ToyTerrain.smoothstep(0.5, 0.9, land[index]))
                    heights[index] = shelf + Float(rise * onLand)
                    relief[index] = shelf / peak + Float(summit * onLand)
                }
            }
            return (heights, relief)
        }
    }
}

struct ToyTerrain {
    struct Shape {
        let surface: ToySurface
        let normalMap: [Float16]
    }

    static let plateHeight = 0.02

    let shapes: [ToyShape: Shape]
    let indices: [UInt32]
    let oceanMask: [UInt8]
    let oceanMaskWidth: Int
    let oceanMaskHeight: Int
    let normalMapWidth: Int
    let normalMapHeight: Int

    init?(waterMaskURL: URL) {
        guard let water = Self.decodeGray(url: waterMaskURL) else { return nil }
        let width = water.width
        let height = water.height
        let degree = Double(width) / 360

        let land = water.values.map { 1 - $0 }
        let coastline = Self.blur(land, width: width, height: height, sigma: 0.5 * degree)
            .map { Self.smoothstep(0.35, 0.55, $0) }
        oceanMask = coastline.map { UInt8(((1 - $0) * 255).rounded()) }
        oceanMaskWidth = width
        oceanMaskHeight = height

        let fieldWidth = width / 2
        let fieldHeight = height / 2
        let coarse = Self.halve(coastline, width: width, height: height)
        normalMapWidth = fieldWidth
        normalMapHeight = fieldHeight

        var shapes: [ToyShape: Shape] = [:]
        for shape in ToyShape.allCases {
            let terrain = shape.terrain(from: coarse, width: fieldWidth, height: fieldHeight, degree: degree / 2)
            let field = HeightField(values: terrain.heights, width: fieldWidth, height: fieldHeight)
            let relief = HeightField(values: terrain.relief, width: fieldWidth, height: fieldHeight)
            shapes[shape] = Shape(surface: Self.surface(for: field), normalMap: Self.normalMap(for: field, relief: relief))
        }
        self.shapes = shapes
        indices = Self.indices()
    }

    fileprivate static func direction(column: Int, row: Int, width: Int, height: Int) -> SIMD3<Double> {
        let latitude = (0.5 - (Double(row) + 0.5) / Double(height)) * .pi
        let longitude = ((Double(column) + 0.5) / Double(width) - 0.5) * 2 * .pi
        return SIMD3(cos(latitude) * sin(longitude), sin(latitude), cos(latitude) * cos(longitude))
    }

    fileprivate static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }

    fileprivate static func blur(_ values: [Float], width: Int, height: Int, sigma: Double) -> [Float] {
        let radius = max(Int((sigma * 3).rounded(.up)), 1)
        let weights = (-radius...radius).map { Float(exp(-Double($0 * $0) / (2 * sigma * sigma))) }
        let total = weights.reduce(0, +)
        let kernel = weights.map { $0 / total }
        let paddedWidth = width + 2 * radius
        var padded = [Float](repeating: 0, count: paddedWidth * height)
        values.withUnsafeBufferPointer { source in
            padded.withUnsafeMutableBufferPointer { target in
                for row in 0..<height {
                    let input = source.baseAddress! + row * width
                    let output = target.baseAddress! + row * paddedWidth
                    output.update(from: input + width - radius, count: radius)
                    (output + radius).update(from: input, count: width)
                    (output + radius + width).update(from: input, count: radius)
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

    private static func surface(for field: HeightField) -> ToySurface {
        let cells = ToySurface.cellsPerFace
        let side = cells + 1
        var vertices: [ToyVertex] = []
        vertices.reserveCapacity(ToySurface.faces.count * side * side)
        for face in ToySurface.faces {
            for j in 0...cells {
                for i in 0...cells {
                    let direction = ToySurface.direction(on: face, i: i, j: j)
                    let lift = field.sample(direction)
                    let position = SIMD3<Float>(direction * (1 + lift))
                    vertices.append(ToyVertex(position: SIMD4(position, Float(lift))))
                }
            }
        }
        return ToySurface(vertices: vertices)
    }

    private static func normalMap(for field: HeightField, relief: HeightField) -> [Float16] {
        var normalMap = [Float16](repeating: 0, count: field.width * field.height * 4)
        for row in 0..<field.height {
            for column in 0..<field.width {
                let direction = Self.direction(column: column, row: row, width: field.width, height: field.height)
                let normal = field.normal(at: direction, lift: field.sample(direction))
                let index = (row * field.width + column) * 4
                normalMap[index] = Float16(normal.x)
                normalMap[index + 1] = Float16(normal.y)
                normalMap[index + 2] = Float16(normal.z)
                normalMap[index + 3] = Float16(relief.sample(direction))
            }
        }
        return normalMap
    }

    private static func indices() -> [UInt32] {
        let cells = ToySurface.cellsPerFace
        let side = cells + 1
        var indices: [UInt32] = []
        indices.reserveCapacity(ToySurface.faces.count * cells * cells * 6)
        for faceIndex in ToySurface.faces.indices {
            let base = UInt32(faceIndex * side * side)
            for j in 0..<cells {
                for i in 0..<cells {
                    let corner = base + UInt32(j * side + i)
                    let right = corner + 1
                    let above = corner + UInt32(side)
                    let diagonal = above + 1
                    indices.append(contentsOf: [corner, right, diagonal, corner, diagonal, above])
                }
            }
        }
        return indices
    }

    private static func halve(_ values: [Float], width: Int, height: Int) -> [Float] {
        let halfWidth = width / 2
        let halfHeight = height / 2
        var result = [Float](repeating: 0, count: halfWidth * halfHeight)
        for y in 0..<halfHeight {
            for x in 0..<halfWidth {
                let top = (2 * y) * width + 2 * x
                let bottom = top + width
                result[y * halfWidth + x] = (values[top] + values[top + 1] + values[bottom] + values[bottom + 1]) / 4
            }
        }
        return result
    }

    private static func decodeGray(url: URL) -> (values: [Float], width: Int, height: Int)? {
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
        return (pixels.map { Float($0) / 255 }, width, height)
    }
}

private struct HeightField {
    let values: [Float]
    let width: Int
    let height: Int

    func sample(_ direction: SIMD3<Double>) -> Double {
        let longitude = atan2(direction.x, direction.z)
        let latitude = asin(min(max(direction.y, -1), 1))
        let x = (longitude / (2 * .pi) + 0.5) * Double(width) - 0.5
        let y = (0.5 - latitude / .pi) * Double(height) - 0.5
        let left = Int(floor(x))
        let top = Int(floor(y))
        let fx = x - Double(left)
        let fy = y - Double(top)
        let upper = value(left, top) * (1 - fx) + value(left + 1, top) * fx
        let lower = value(left, top + 1) * (1 - fx) + value(left + 1, top + 1) * fx
        return upper * (1 - fy) + lower * fy
    }

    func normal(at d: SIMD3<Double>, lift: Double) -> SIMD3<Double> {
        let helper: SIMD3<Double> = abs(d.y) < 0.9 ? SIMD3(0, 1, 0) : SIMD3(1, 0, 0)
        let first = normalize(cross(helper, d))
        let second = cross(d, first)
        let step = 0.004
        let slopeFirst = (sample(normalize(d + first * step)) - sample(normalize(d - first * step))) / (2 * step)
        let slopeSecond = (sample(normalize(d + second * step)) - sample(normalize(d - second * step))) / (2 * step)
        return normalize(d * (1 + lift) - first * slopeFirst - second * slopeSecond)
    }

    private func value(_ x: Int, _ y: Int) -> Double {
        let column = ((x % width) + width) % width
        let row = min(max(y, 0), height - 1)
        return Double(values[row * width + column])
    }
}
