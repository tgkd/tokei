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
    static let meshSampleCount = 4

    let device: MTLDevice
    let queue: MTLCommandQueue
    private let pipeline: MTLRenderPipelineState
    private let effectsPipeline: MTLRenderPipelineState
    private let meshPipelines: [String: MTLRenderPipelineState]
    private let backgroundPipelines: [String: MTLRenderPipelineState]
    private let meshDepthState: MTLDepthStencilState
    private let backgroundDepthState: MTLDepthStencilState
    private let reliefPipeline: MTLComputePipelineState
    private let surfaceSampler: MTLSamplerState
    private let lutSampler: MTLSamplerState
    private let transmittance: MTLTexture
    private let placeholder: MTLTexture
    private(set) var textures: GlobeTextures?
    private(set) var toyMesh: ToyMesh?
    let snowCover: SnowCover?
    private var meshTargets: (color: MTLTexture, depth: MTLTexture)?

    init?(device: MTLDevice? = MTLCreateSystemDefaultDevice(), library: MTLLibrary? = nil) {
        guard
            let device,
            let queue = device.makeCommandQueue(),
            let library = library ?? device.makeDefaultLibrary(),
            let vertexFunction = library.makeFunction(name: "globeVertex"),
            let fragmentFunction = Self.realisticFragment(in: library, effects: false),
            let effectsFragmentFunction = Self.realisticFragment(in: library, effects: true),
            let meshVertexFunction = library.makeFunction(name: "meshVertex"),
            let reliefKernel = library.makeFunction(name: "reliefKernel"),
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

        var meshPipelines: [String: MTLRenderPipelineState] = [:]
        for fragment in Set(SceneStyle.allCases.compactMap(\.mesh?.fragment)) {
            let meshDescriptor = MTLRenderPipelineDescriptor()
            meshDescriptor.vertexFunction = meshVertexFunction
            meshDescriptor.fragmentFunction = library.makeFunction(name: fragment)
            meshDescriptor.colorAttachments[0].pixelFormat = Self.pixelFormat
            meshDescriptor.depthAttachmentPixelFormat = .depth32Float
            meshDescriptor.rasterSampleCount = Self.meshSampleCount
            guard meshDescriptor.fragmentFunction != nil, let state = try? device.makeRenderPipelineState(descriptor: meshDescriptor) else { return nil }
            meshPipelines[fragment] = state
        }

        var backgroundPipelines: [String: MTLRenderPipelineState] = [:]
        for fragment in Set(SceneStyle.allCases.compactMap(\.mesh?.background)) {
            let backgroundDescriptor = MTLRenderPipelineDescriptor()
            backgroundDescriptor.vertexFunction = vertexFunction
            backgroundDescriptor.fragmentFunction = library.makeFunction(name: fragment)
            backgroundDescriptor.colorAttachments[0].pixelFormat = Self.pixelFormat
            backgroundDescriptor.depthAttachmentPixelFormat = .depth32Float
            backgroundDescriptor.rasterSampleCount = Self.meshSampleCount
            guard backgroundDescriptor.fragmentFunction != nil, let state = try? device.makeRenderPipelineState(descriptor: backgroundDescriptor) else { return nil }
            backgroundPipelines[fragment] = state
        }

        let backgroundDepth = MTLDepthStencilDescriptor()
        backgroundDepth.depthCompareFunction = .always
        backgroundDepth.isDepthWriteEnabled = false

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
            let meshDepthState = device.makeDepthStencilState(descriptor: depth),
            let backgroundDepthState = device.makeDepthStencilState(descriptor: backgroundDepth),
            let reliefPipeline = try? device.makeComputePipelineState(function: reliefKernel),
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
        self.meshPipelines = meshPipelines
        self.backgroundPipelines = backgroundPipelines
        self.meshDepthState = meshDepthState
        self.backgroundDepthState = backgroundDepthState
        self.reliefPipeline = reliefPipeline
        self.surfaceSampler = surfaceSampler
        self.lutSampler = lutSampler
        self.transmittance = transmittance
        self.placeholder = placeholder
    }

    var isReady: Bool {
        textures != nil
    }

    func loadTextures(resources: GlobeResources = .main, style: SceneStyle = .load()) async {
        guard textures == nil else { return }
        let device = device
        let queue = queue
        let first = style.mesh?.shape
        let loadedMesh = Task.detached(priority: first == nil ? .utility : .userInitiated) {
            ToyMesh.load(device: device, queue: queue, resources: resources, first: first)
        }
        let loadedTextures = await Task.detached(priority: .userInitiated) {
            GlobeTextures.load(device: device, queue: queue, resources: resources)
        }.value
        if first == nil {
            textures = loadedTextures
            Task {
                attach(await loadedMesh.value, first: nil)
            }
        } else {
            attach(await loadedMesh.value, first: first)
            textures = loadedTextures
        }
    }

    private func attach(_ mesh: ToyMesh?, first: ToyShape?) {
        guard let mesh else { return }
        toyMesh = mesh
        if let first, let shape = mesh.shapes[first], let commandBuffer = queue.makeCommandBuffer() {
            encodeRelief(shape, of: mesh, commandBuffer: commandBuffer)
            mesh.markRelief(first)
            commandBuffer.commit()
        }
        Task {
            await completeShapes(of: mesh)
        }
    }

    private func completeShapes(of mesh: ToyMesh) async {
        guard let terrain = mesh.terrain else { return }
        let device = device
        for key in ToyShape.allCases where mesh.shapes[key] == nil {
            let shape = await Task.detached(priority: .utility) {
                terrain.shape(key, device: device)
            }.value
            if let shape {
                mesh.add(shape, for: key, device: device)
            }
        }
        mesh.finishBuilding()
    }

    func draw(_ frame: GlobeFrame, reveal: Float, scale: CGFloat, to layer: CAMetalLayer) {
        guard
            let drawable = layer.nextDrawable(),
            let commandBuffer = queue.makeCommandBuffer(),
            encode(frame, reveal: reveal, scale: Float(scale), into: drawable.texture, commandBuffer: commandBuffer)
        else { return }

        commandBuffer.commit()
        commandBuffer.waitUntilScheduled()
        drawable.present()
    }

    func encode(_ frame: GlobeFrame, reveal: Float, scale: Float, into target: MTLTexture, commandBuffer: MTLCommandBuffer) -> Bool {
        var uniforms = makeUniforms(frame, reveal: textures == nil ? 0 : reveal, scale: scale)
        var effects = frame.effects.uniforms
        let look = frame.style.look
        if let mesh = look.mesh {
            return encodeMesh(mesh, frame: frame, clearColor: look.clearColor, uniforms: &uniforms, effects: &effects, into: target, commandBuffer: commandBuffer)
        }
        return encodeRealistic(uniforms: &uniforms, effects: &effects, into: target, commandBuffer: commandBuffer)
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
        encoder.setFragmentTexture(textures?.clouds ?? placeholder, index: 4)
        encoder.setFragmentTexture(textures?.relief ?? placeholder, index: 5)
        encoder.setFragmentSamplerState(surfaceSampler, index: 0)
        encoder.setFragmentSamplerState(lutSampler, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        return true
    }

    private func encodeMesh(
        _ look: MeshLook,
        frame: GlobeFrame,
        clearColor: MTLClearColor,
        uniforms: inout GlobeUniforms,
        effects: inout EffectUniforms,
        into target: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) -> Bool {
        guard let targets = meshTargets(matching: target) else { return false }
        let selected = toyMesh?.shape(for: look.shape)
        if let mesh = toyMesh, let selected, mesh.reliefShape != selected.key {
            encodeRelief(selected.shape, of: mesh, commandBuffer: commandBuffer)
            mesh.markRelief(selected.key)
        }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = targets.color
        pass.colorAttachments[0].resolveTexture = target
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = clearColor
        pass.colorAttachments[0].storeAction = .multisampleResolve
        pass.depthAttachment.texture = targets.depth
        pass.depthAttachment.loadAction = .clear
        pass.depthAttachment.clearDepth = 1
        pass.depthAttachment.storeAction = .dontCare

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass) else { return false }
        if let name = look.background, let background = backgroundPipelines[name] {
            encoder.setRenderPipelineState(background)
            encoder.setDepthStencilState(backgroundDepthState)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GlobeUniforms>.stride, index: 0)
            look.parameters.withUnsafeBytes { bytes in
                encoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 1)
            }
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        }
        if let mesh = toyMesh, let shape = selected?.shape, let textures, let pipeline = meshPipelines[look.fragment] {
            encoder.setRenderPipelineState(pipeline)
            encoder.setDepthStencilState(meshDepthState)
            encoder.setFrontFacing(.counterClockwise)
            encoder.setCullMode(.back)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<GlobeUniforms>.stride, index: 0)
            encoder.setVertexBytes(&effects, length: MemoryLayout<EffectUniforms>.stride, index: 2)
            encoder.setVertexBuffer(shape.surface.coast.buffer, offset: 0, index: 4)
            encoder.setVertexBuffer(shape.surface.lift.buffer, offset: 0, index: 5)
            encoder.setVertexBuffer(shape.profile, offset: 0, index: 6)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<GlobeUniforms>.stride, index: 0)
            look.parameters.withUnsafeBytes { bytes in
                encoder.setFragmentBytes(bytes.baseAddress!, length: bytes.count, index: 1)
            }
            encoder.setFragmentBytes(&effects, length: MemoryLayout<EffectUniforms>.stride, index: 2)
            encoder.setFragmentTexture(textures.day, index: 0)
            encoder.setFragmentTexture(textures.lights, index: 1)
            encoder.setFragmentTexture(mesh.coast, index: 2)
            encoder.setFragmentTexture(mesh.relief, index: 3)
            encoder.setFragmentTexture(snowCover?.texture ?? placeholder, index: 4)
            encoder.setFragmentSamplerState(surfaceSampler, index: 0)
            for (slot, var nodes) in shape.surface.nodes(in: frame).enumerated() where !nodes.isEmpty {
                var terrain = mesh.uniforms(for: shape, grid: ToySurface.grids[slot])
                let nodeBytes = nodes.count * MemoryLayout<UInt32>.stride
                if nodeBytes <= 4096 {
                    encoder.setVertexBytes(&nodes, length: nodeBytes, index: 1)
                } else {
                    encoder.setVertexBuffer(device.makeBuffer(bytes: &nodes, length: nodeBytes), offset: 0, index: 1)
                }
                encoder.setVertexBytes(&terrain, length: MemoryLayout<TerrainUniforms>.stride, index: 3)
                let range = mesh.indexRanges[slot]
                encoder.drawIndexedPrimitives(
                    type: .triangle,
                    indexCount: range.count,
                    indexType: .uint16,
                    indexBuffer: mesh.indices,
                    indexBufferOffset: range.lowerBound * MemoryLayout<UInt16>.stride,
                    instanceCount: nodes.count
                )
            }
        }
        encoder.endEncoding()
        return true
    }

    private func encodeRelief(_ shape: ToyMesh.Shape, of mesh: ToyMesh, commandBuffer: MTLCommandBuffer) {
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        var terrain = mesh.uniforms(for: shape, grid: ToySurface.grids[0])
        encoder.setComputePipelineState(reliefPipeline)
        encoder.setTexture(mesh.relief, index: 0)
        encoder.setBytes(&terrain, length: MemoryLayout<TerrainUniforms>.stride, index: 0)
        encoder.setBuffer(shape.surface.coast.buffer, offset: 0, index: 1)
        encoder.setBuffer(shape.surface.lift.buffer, offset: 0, index: 2)
        encoder.setBuffer(shape.relief.buffer, offset: 0, index: 3)
        encoder.setBuffer(shape.profile, offset: 0, index: 4)
        let threads = MTLSize(width: 16, height: 16, depth: 1)
        let groups = MTLSize(width: (mesh.relief.width + 15) / 16, height: (mesh.relief.height + 15) / 16, depth: 1)
        encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: threads)
        encoder.endEncoding()
        guard let blit = commandBuffer.makeBlitCommandEncoder() else { return }
        blit.generateMipmaps(for: mesh.relief)
        blit.endEncoding()
    }

    private func meshTargets(matching target: MTLTexture) -> (color: MTLTexture, depth: MTLTexture)? {
        if let meshTargets, meshTargets.color.width == target.width, meshTargets.color.height == target.height {
            return meshTargets
        }
        guard
            let color = makeMultisampleTexture(format: Self.pixelFormat, width: target.width, height: target.height),
            let depth = makeMultisampleTexture(format: .depth32Float, width: target.width, height: target.height)
        else { return nil }
        meshTargets = (color, depth)
        return meshTargets
    }

    private func makeMultisampleTexture(format: MTLPixelFormat, width: Int, height: Int) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
        descriptor.textureType = .type2DMultisample
        descriptor.sampleCount = Self.meshSampleCount
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
