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
    static let toySampleCount = 4

    let device: MTLDevice
    private let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let effectsPipeline: MTLRenderPipelineState
    private let toyPipeline: MTLRenderPipelineState
    private let toyDepthState: MTLDepthStencilState
    private let surfaceSampler: MTLSamplerState
    private let lutSampler: MTLSamplerState
    private let transmittance: MTLTexture
    private let placeholder: MTLTexture
    private(set) var textures: GlobeTextures?
    private(set) var toyMesh: ToyMesh?
    let snowCover: SnowCover?
    private var toyTargets: (color: MTLTexture, depth: MTLTexture)?

    init?() {
        guard
            let device = MTLCreateSystemDefaultDevice(),
            let queue = device.makeCommandQueue(),
            let library = device.makeDefaultLibrary(),
            let vertexFunction = library.makeFunction(name: "globeVertex"),
            let fragmentFunction = Self.realisticFragment(in: library, effects: false),
            let effectsFragmentFunction = Self.realisticFragment(in: library, effects: true),
            let toyVertexFunction = library.makeFunction(name: "toyVertex"),
            let toyFragmentFunction = library.makeFunction(name: "globeFragmentToyMesh"),

            let kernel = library.makeFunction(name: "transmittanceKernel")
        else { return nil }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = Self.pixelFormat

        let effectsDescriptor = MTLRenderPipelineDescriptor()
        effectsDescriptor.vertexFunction = vertexFunction
        effectsDescriptor.fragmentFunction = effectsFragmentFunction
        effectsDescriptor.colorAttachments[0].pixelFormat = Self.pixelFormat

        let toyDescriptor = MTLRenderPipelineDescriptor()
        toyDescriptor.vertexFunction = toyVertexFunction
        toyDescriptor.fragmentFunction = toyFragmentFunction
        toyDescriptor.colorAttachments[0].pixelFormat = Self.pixelFormat
        toyDescriptor.depthAttachmentPixelFormat = .depth32Float
        toyDescriptor.rasterSampleCount = Self.toySampleCount

        let depth = MTLDepthStencilDescriptor()
        depth.depthCompareFunction = .less
        depth.isDepthWriteEnabled = true

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
            let effectsPipeline = try? device.makeRenderPipelineState(descriptor: effectsDescriptor),
            let toyPipeline = try? device.makeRenderPipelineState(descriptor: toyDescriptor),
            let toyDepthState = device.makeDepthStencilState(descriptor: depth),
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
        snowCover = SnowCover(device: device)
        self.pipeline = pipeline
        self.effectsPipeline = effectsPipeline
        self.toyPipeline = toyPipeline
        self.toyDepthState = toyDepthState
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
        async let loadedTextures = Task.detached(priority: .userInitiated) {
            GlobeTextures.load(device: device, queue: queue)
        }.value
        async let loadedMesh = Task.detached(priority: .userInitiated) {
            ToyMesh.load(device: device, queue: queue)
        }.value
        let (textures, mesh) = await (loadedTextures, loadedMesh)
        toyMesh = mesh
        self.textures = textures
    }

    func draw(_ frame: GlobeFrame, reveal: Float, scale: CGFloat, to layer: CAMetalLayer) {
        guard
            let drawable = layer.nextDrawable(),
            let commandBuffer = queue.makeCommandBuffer()
        else { return }

        var uniforms = makeUniforms(frame, reveal: textures == nil ? 0 : reveal, scale: Float(scale))
        var effects = frame.effects.uniforms
        let encoded = if let palette = frame.style.toyPalette {
            encodeToy(
                uniforms: &uniforms,
                effects: &effects,
                palette: palette,
                material: frame.style.toyMaterial,
                shape: frame.style.toyShape,
                into: drawable.texture,
                commandBuffer: commandBuffer
            )
        } else {
            encodeRealistic(uniforms: &uniforms, effects: &effects, into: drawable.texture, commandBuffer: commandBuffer)
        }
        guard encoded else { return }

        commandBuffer.commit()
        commandBuffer.waitUntilScheduled()
        drawable.present()
    }

    private func encodeRealistic(uniforms: inout GlobeUniforms, effects: inout EffectUniforms, into target: MTLTexture, commandBuffer: MTLCommandBuffer) -> Bool {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return false }
        encoder.setRenderPipelineState(effects.state.y > 0.5 ? effectsPipeline : pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GlobeUniforms>.stride, index: 0)
        encoder.setFragmentBytes(&effects, length: MemoryLayout<EffectUniforms>.stride, index: 2)
        encoder.setFragmentTexture(textures?.day ?? placeholder, index: 0)
        encoder.setFragmentTexture(textures?.lights ?? placeholder, index: 1)
        encoder.setFragmentTexture(textures?.water ?? placeholder, index: 2)
        encoder.setFragmentTexture(transmittance, index: 3)
        encoder.setFragmentSamplerState(surfaceSampler, index: 0)
        encoder.setFragmentSamplerState(lutSampler, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        return true
    }

    private func encodeToy(
        uniforms: inout GlobeUniforms,
        effects: inout EffectUniforms,
        palette: ToyPalette,
        material: ToyMaterial,
        shape: ToyShape,
        into target: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) -> Bool {
        guard let targets = toyTargets(matching: target) else { return false }
        var palette = palette
        var material = material
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = targets.color
        pass.colorAttachments[0].resolveTexture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = palette.clearColor
        pass.colorAttachments[0].storeAction = .multisampleResolve
        pass.depthAttachment.texture = targets.depth
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 1
        pass.depthAttachment.storeAction = .dontCare

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return false }
        if let mesh = toyMesh, let meshShape = mesh.shapes[shape], let textures {
            encoder.setRenderPipelineState(toyPipeline)
            encoder.setDepthStencilState(toyDepthState)
            encoder.setFrontFacing(.counterClockwise)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<GlobeUniforms>.stride, index: 0)
            encoder.setVertexBuffer(meshShape.vertices, offset: 0, index: 1)
            encoder.setVertexBytes(&effects, length: MemoryLayout<EffectUniforms>.stride, index: 2)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GlobeUniforms>.stride, index: 0)
            encoder.setFragmentBytes(&palette, length: MemoryLayout<ToyPalette>.stride, index: 1)
            encoder.setFragmentBytes(&effects, length: MemoryLayout<EffectUniforms>.stride, index: 2)
            encoder.setFragmentBytes(&material, length: MemoryLayout<ToyMaterial>.stride, index: 3)
            encoder.setFragmentTexture(textures.day, index: 0)
            encoder.setFragmentTexture(textures.lights, index: 1)
            encoder.setFragmentTexture(mesh.ocean, index: 2)
            encoder.setFragmentTexture(meshShape.normals, index: 3)
            encoder.setFragmentTexture(snowCover?.texture ?? placeholder, index: 4)
            encoder.setFragmentSamplerState(surfaceSampler, index: 0)
            encoder.drawIndexedPrimitives(type: .triangle, indexCount: mesh.indexCount, indexType: .uint32, indexBuffer: mesh.indices, indexBufferOffset: 0)
        }
        encoder.endEncoding()
        return true
    }

    private func toyTargets(matching target: MTLTexture) -> (color: MTLTexture, depth: MTLTexture)? {
        if let toyTargets, toyTargets.color.width == target.width, toyTargets.color.height == target.height {
            return toyTargets
        }
        guard
            let color = makeMultisampleTexture(format: Self.pixelFormat, width: target.width, height: target.height),
            let depth = makeMultisampleTexture(format: .depth32Float, width: target.width, height: target.height)
        else { return nil }
        toyTargets = (color, depth)
        return toyTargets
    }

    private func makeMultisampleTexture(format: MTLPixelFormat, width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        descriptor.textureType = .type2DMultisample
        descriptor.sampleCount = Self.toySampleCount
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .memoryless
        if let texture = device.makeTexture(descriptor: descriptor) {
            return texture
        }
        descriptor.storageMode = .private
        return device.makeTexture(descriptor: descriptor)
    }

    private static func realisticFragment(in library: MTLLibrary, effects: Bool) -> MTLFunction? {
        let constants = MTLFunctionConstantValues()
        var enabled = effects
        constants.setConstantValue(&enabled, type: .bool, index: 0)
        return try? library.makeFunction(name: "globeFragment", constantValues: constants)
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
