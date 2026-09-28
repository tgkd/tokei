import Foundation
import Metal

struct ToyMesh {
    struct Shape {
        let surface: ToySurface
        let vertices: MTLBuffer
        let normals: MTLTexture
    }

    let shapes: [ToyShape: Shape]
    let indices: MTLBuffer
    let indexCount: Int
    let ocean: MTLTexture

    static func load(device: MTLDevice, queue: MTLCommandQueue) -> ToyMesh? {
        guard
            let url = Bundle.main.url(forResource: "earth-water", withExtension: "png"),
            let terrain = ToyTerrain(waterMaskURL: url),
            let indices = terrain.indices.withUnsafeBytes({ device.makeBuffer(bytes: $0.baseAddress!, length: $0.count) }),
            let ocean = makeTexture(
                terrain.oceanMask,
                format: .r8Unorm,
                width: terrain.oceanMaskWidth,
                height: terrain.oceanMaskHeight,
                bytesPerPixel: 1,
                device: device
            ),
            let commandBuffer = queue.makeCommandBuffer(),
            let blit = commandBuffer.makeBlitCommandEncoder()
        else { return nil }
        blit.generateMipmaps(for: ocean)
        var shapes: [ToyShape: Shape] = [:]
        for (shape, data) in terrain.shapes {
            guard
                let vertices = data.surface.vertices.withUnsafeBytes({ device.makeBuffer(bytes: $0.baseAddress!, length: $0.count) }),
                let normals = makeTexture(
                    data.normalMap,
                    format: .rgba16Float,
                    width: terrain.normalMapWidth,
                    height: terrain.normalMapHeight,
                    bytesPerPixel: 8,
                    device: device
                )
            else { continue }
            blit.generateMipmaps(for: normals)
            shapes[shape] = Shape(surface: data.surface, vertices: vertices, normals: normals)
        }
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard shapes.count == ToyShape.allCases.count else { return nil }
        return ToyMesh(shapes: shapes, indices: indices, indexCount: terrain.indices.count, ocean: ocean)
    }

    private static func makeTexture<Element>(
        _ pixels: [Element],
        format: MTLPixelFormat,
        width: Int,
        height: Int,
        bytesPerPixel: Int,
        device: MTLDevice
    ) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: true)
        descriptor.usage = [.shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else { return nil }
        pixels.withUnsafeBytes { bytes in
            texture.replace(region: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0, withBytes: bytes.baseAddress!, bytesPerRow: width * bytesPerPixel)
        }
        return texture
    }
}
