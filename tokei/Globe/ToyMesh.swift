import Foundation
import Metal

struct TerrainUniforms {
    var coast: SIMD4<Float>
    var lift: SIMD4<Float>
    var relief: SIMD4<Float>
    var profile: SIMD4<Float>
    var grid: SIMD4<Float>
}

final class ToyMesh {
    struct Shape {
        let surface: ToySurface
        let relief: TerrainGrid
        let profile: MTLBuffer
    }

    static let reliefWidth = 2048
    static let reliefHeight = 1024

    private(set) var shapes: [ToyShape: Shape] = [:]
    private(set) var terrain: ToyTerrain?
    private(set) var reliefShape: ToyShape?
    let coast: MTLTexture
    let relief: MTLTexture
    let indices: MTLBuffer
    let indexRanges: [Range<Int>]

    private init(terrain: ToyTerrain, coast: MTLTexture, relief: MTLTexture, indices: MTLBuffer, indexRanges: [Range<Int>]) {
        self.terrain = terrain
        self.coast = coast
        self.relief = relief
        self.indices = indices
        self.indexRanges = indexRanges
    }

    static func load(device: MTLDevice, queue: MTLCommandQueue, resources: GlobeResources, first: ToyShape?) -> ToyMesh? {
        var indices: [UInt16] = []
        var indexRanges: [Range<Int>] = []
        for grid in ToySurface.grids {
            let start = indices.count
            indices.append(contentsOf: Self.indices(grid: grid))
            indexRanges.append(start..<indices.count)
        }
        guard
            let url = resources.url("earth-water", "png"),
            let terrain = ToyTerrain(waterMaskURL: url, device: device),
            let indexBuffer = indices.withUnsafeBytes({ device.makeBuffer(bytes: $0.baseAddress!, length: $0.count) }),
            let coast = makeTexture(format: .r16Float, width: terrain.coast.width, height: terrain.coast.height, usage: [.shaderRead], device: device),
            let relief = makeTexture(format: .rgba16Float, width: reliefWidth, height: reliefHeight, usage: [.shaderRead, .shaderWrite], device: device),
            let commandBuffer = queue.makeCommandBuffer(),
            let blit = commandBuffer.makeBlitCommandEncoder()
        else { return nil }
        let width = terrain.coast.width
        let height = terrain.coast.height
        blit.copy(
            from: terrain.coast.buffer,
            sourceOffset: 0,
            sourceBytesPerRow: width * MemoryLayout<Float16>.stride,
            sourceBytesPerImage: width * height * MemoryLayout<Float16>.stride,
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: coast,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin()
        )
        blit.generateMipmaps(for: coast)
        blit.endEncoding()
        commandBuffer.commit()
        let mesh = ToyMesh(terrain: terrain, coast: coast, relief: relief, indices: indexBuffer, indexRanges: indexRanges)
        if let first, let shape = terrain.shape(first, device: device) {
            mesh.add(shape, for: first, device: device)
        }
        commandBuffer.waitUntilCompleted()
        return mesh
    }

    func add(_ shape: ToyTerrain.Shape, for key: ToyShape, device: MTLDevice) {
        let profile = shape.surface.profile
        guard let buffer = profile.withUnsafeBytes({ device.makeBuffer(bytes: $0.baseAddress!, length: $0.count) }) else { return }
        shapes[key] = Shape(surface: shape.surface, relief: shape.relief, profile: buffer)
    }

    func finishBuilding() {
        terrain = nil
    }

    func shape(for key: ToyShape) -> (key: ToyShape, shape: Shape)? {
        if let shape = shapes[key] {
            return (key, shape)
        }
        return shapes.first.map { ($0.key, $0.value) }
    }

    func uniforms(for shape: Shape, grid: Int) -> TerrainUniforms {
        let coastGrid = shape.surface.coast
        let lift = shape.surface.lift
        return TerrainUniforms(
            coast: SIMD4(Float(coastGrid.width), Float(coastGrid.height), 0, 0),
            lift: SIMD4(Float(lift.width), Float(lift.height), 0, 0),
            relief: SIMD4(Float(shape.relief.width), Float(shape.relief.height), 0, 0),
            profile: SIMD4(Float(TerrainProfile.start), Float(TerrainProfile.step), Float(TerrainProfile.count), 0),
            grid: SIMD4(Float(grid), 0, 0, 0)
        )
    }

    func markRelief(_ key: ToyShape) {
        reliefShape = key
    }

    private static func indices(grid cells: Int) -> [UInt16] {
        let side = cells + 1
        var indices: [UInt16] = []
        indices.reserveCapacity(cells * cells * 6 + cells * 4 * 6)
        for j in 0..<cells {
            for i in 0..<cells {
                let corner = UInt16(j * side + i)
                let right = corner + 1
                let above = corner + UInt16(side)
                let diagonal = above + 1
                indices.append(contentsOf: [corner, right, diagonal, corner, diagonal, above])
            }
        }
        let ring = (0..<(cells * 4)).map { step -> Int in
            let edge = step / cells
            let offset = step % cells
            switch edge {
            case 0: return offset
            case 1: return offset * side + cells
            case 2: return cells * side + cells - offset
            default: return (cells - offset) * side
            }
        }
        let skirtBase = side * side
        for step in 0..<ring.count {
            let next = (step + 1) % ring.count
            let top = UInt16(ring[step])
            let topNext = UInt16(ring[next])
            let bottom = UInt16(skirtBase + step)
            let bottomNext = UInt16(skirtBase + next)
            indices.append(contentsOf: [top, bottom, topNext, topNext, bottom, bottomNext])
        }
        return indices
    }

    private static func makeTexture(format: MTLPixelFormat, width: Int, height: Int, usage: MTLTextureUsage, device: MTLDevice) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: true)
        descriptor.usage = usage
        descriptor.storageMode = .private
        return device.makeTexture(descriptor: descriptor)
    }
}
