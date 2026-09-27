import Metal
import QuartzCore
import simd

struct GlobeUniforms {
    var cameraPosition: SIMD4<Float>
    var cameraRight: SIMD4<Float>
    var cameraUp: SIMD4<Float>
    var cameraForward: SIMD4<Float>
    var sunDirection: SIMD4<Float>
    var viewport: SIMD4<Float>
    var principal: SIMD4<Float>
}

@MainActor
final class GlobeRenderer {
    static let pixelFormat: MTLPixelFormat = .bgra8Unorm
    static let exposure: Float = 4.5

    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let surfaceSampler: MTLSamplerState
    private let lutSampler: MTLSamplerState
    private let transmittance: MTLTexture
    private let placeholder: MTLTexture
    private(set) var textures: GlobeTextures?

    init?() {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue(),
            let library = device.makeDefaultLibrary(),
            let vertexFunction = library.makeFunction(name: "globeVertex"),
            let fragmentFunction = library.makeFunction(name: "globeFragment"),
            let kernel = library.makeFunction(name: "transmittanceKernel")
        else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = Self.pixelFormat

        let surface = MTLSamplerDescriptor()
        surface.minFilter = .linear
        surface.magFilter = .linear
        surface.mipFilter = .linear
        surface.sAddressMode = .repeat
        surface.tAddressMode = .clampToEdge
        surface.maxAnisotropy = 8

        let lookup = MTLSamplerDescriptor()
        lookup.minFilter = .linear
        lookup.magFilter = .linear
        lookup.sAddressMode = .clampToEdge
        lookup.tAddressMode = .clampToEdge

        let lutDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: 256, height: 64, mipmapped: false)
        lutDescriptor.usage = [.shaderRead, .shaderWrite]
        lutDescriptor.storageMode = .private

        let placeholderDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 1, height: 1, mipmapped: false)
        placeholderDescriptor.usage = [.shaderRead]

        guard
            let pipeline = try? device.makeRenderPipelineState(descriptor: descriptor),
            let compute = try? device.makeComputePipelineState(function: kernel),
            let surfaceSampler = device.makeSamplerState(descriptor: surface),
            let lutSampler = device.makeSamplerState(descriptor: lookup),
            let transmittance = device.makeTexture(descriptor: lutDescriptor),
            let placeholder = device.makeTexture(descriptor: placeholderDescriptor),
            let commandBuffer = queue.makeCommandBuffer(),
            let encoder = commandBuffer.makeComputeCommandEncoder()
        else { return nil }

        var black: [UInt8] = [0, 0, 0, 255]
        placeholder.replace(region: MTLRegionMake2D(0, 0, 1, 1), mipmapLevel: 0, withBytes: &black, bytesPerRow: 4)

        encoder.setComputePipelineState(compute)
        encoder.setTexture(transmittance, index: 0)
        let threads = MTLSize(width: 16, height: 16, depth: 1)
        let groups = MTLSize(width: (256 + 15) / 16, height: (64 + 15) / 16, depth: 1)
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
        encoder.endEncoding()
        commandBuffer.commit()

        self.device = device
        self.queue = queue
        self.pipeline = pipeline
        self.surfaceSampler = surfaceSampler
        self.lutSampler = lutSampler
        self.transmittance = transmittance
        self.placeholder = placeholder
    }

    var isReady: Bool {
        textures != nil
    }

    func loadTextures() async {
        guard textures == nil else { return }
        let device = device
        let queue = queue
        let loaded = await Task.detached(priority: .userInitiated) {
            GlobeTextures.load(device: device, queue: queue)
        }.value
        textures = loaded
    }

    func draw(_ frame: GlobeFrame, reveal: Float, scale: CGFloat, to layer: CAMetalLayer) {
        guard
            let drawable = layer.nextDrawable(),
            let commandBuffer = queue.makeCommandBuffer()
        else { return }

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return }
        var uniforms = makeUniforms(frame, reveal: textures == nil ? 0 : reveal, scale: Float(scale))
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GlobeUniforms>.stride, index: 0)
        encoder.setFragmentTexture(textures?.day ?? placeholder, index: 0)
        encoder.setFragmentTexture(textures?.lights ?? placeholder, index: 1)
        encoder.setFragmentTexture(textures?.water ?? placeholder, index: 2)
        encoder.setFragmentTexture(transmittance, index: 3)
        encoder.setFragmentSamplerState(surfaceSampler, index: 0)
        encoder.setFragmentSamplerState(lutSampler, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.commit()
        commandBuffer.waitUntilScheduled()
        drawable.present()
    }

    private func makeUniforms(_ frame: GlobeFrame, reveal: Float, scale: Float) -> GlobeUniforms {
        func vector(_ value: SIMD3<Double>) -> SIMD4<Float> {
            SIMD4(Float(value.x), Float(value.y), Float(value.z), 0)
        }
        let width = Float(frame.size.width) * scale
        let height = Float(frame.size.height) * scale
        let focal = Float(frame.focalLength) * scale
        let centerX = Float(frame.center.x) * scale
        let centerY = Float(frame.center.y) * scale
        let viewport = SIMD4<Float>(width, height, focal, Self.exposure)
        let principal = SIMD4<Float>(centerX, centerY, reveal, 0)
        return GlobeUniforms(
            cameraPosition: vector(frame.position),
            cameraRight: vector(frame.right),
            cameraUp: vector(frame.up),
            cameraForward: vector(frame.forward),
            sunDirection: vector(frame.sun),
            viewport: viewport,
            principal: principal
        )
    }
}
