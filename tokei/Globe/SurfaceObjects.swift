import Metal
import simd

struct SurfaceObjectsLook {
    let kind: SurfaceObjectKind
    let vertex: String
    let fragment: String
    let coverage: Bool
    let cullsBack: Bool

    var pipeline: SurfacePipeline {
        SurfacePipeline(vertex: vertex, fragment: fragment, coverage: coverage)
    }
}

struct SurfacePipeline: Hashable {
    let vertex: String
    let fragment: String
    let coverage: Bool
}

enum SurfaceObjectKind: CaseIterable {
    case petalBed
    case yarn
    case tiles

    func build(surface: ToySurface, device: MTLDevice) -> SurfaceObjectSet? {
        switch self {
        case .petalBed: SakuraPetalBed.build(surface: surface, device: device)
        case .yarn: KnitYarn.build(surface: surface, device: device)
        case .tiles: MosaicTiles.build(surface: surface, device: device)
        }
    }
}

struct SurfaceTier {
    let minimumPixels: Float
    let vertexCount: Int
    var indices: MTLBuffer?
    var indexCount = 0
    var primitive: MTLPrimitiveType = .triangle
}

struct SurfaceBounds {
    var center: SIMD3<Float>
    var radius: Float
    var extent: Float
    var size: Float
}

struct SurfaceUniforms {
    var clock: SIMD4<Float>
    var extra: SIMD4<Float>
}

struct SurfaceBatch {
    let tier: Int
    let buffer: MTLBuffer
    let offset: Int
    let count: Int
}

final class SurfaceObjectSet {
    static let patchDegrees: Float = 4
    static let ringSize = 3
    static let batchAlignment = 64

    let instances: MTLBuffer
    let stride: Int
    let count: Int
    let tiers: [SurfaceTier]
    private(set) var revision = 0
    private var bounds: [SurfaceBounds]
    private var probes: [SIMD4<Float>]
    private var reaches: [SIMD4<Float>]
    private var patches: [SurfacePatch]
    private let owners: [Int]
    private let thresholds: [Float]
    private var highest: Float
    private let rings: [MTLBuffer]
    private var ring = 0
    private let scratch: UnsafeMutablePointer<UInt32>?

    init?<Record>(records: [Record], bounds: [SurfaceBounds], tiers: [SurfaceTier], device: MTLDevice) {
        guard !records.isEmpty, records.count == bounds.count, !tiers.isEmpty else { return nil }
        let normalized = bounds.map(SurfaceObjectSet.normalized)
        let layout = SurfaceObjectSet.layout(normalized)
        let ordered = layout.order.map { records[$0] }
        let sorted = layout.order.map { normalized[$0] }
        let count = records.count
        guard let instances = ordered.withUnsafeBytes({ device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) }) else { return nil }
        let slots = count + (tiers.count - 1) * SurfaceObjectSet.batchAlignment
        var rings: [MTLBuffer] = []
        for _ in 0..<SurfaceObjectSet.ringSize {
            guard let ring = device.makeBuffer(length: slots * MemoryLayout<UInt32>.stride, options: .storageModeShared) else { return nil }
            rings.append(ring)
        }
        var owners = [Int](repeating: 0, count: count)
        var patches: [SurfacePatch] = []
        patches.reserveCapacity(layout.ranges.count)
        for range in layout.ranges {
            var sum = SIMD3<Float>.zero
            for index in range {
                sum += sorted[index].center
                owners[index] = patches.count
            }
            let center = length(sum) > 1e-6 ? normalize(sum) : sorted[range.lowerBound].center
            patches.append(SurfaceObjectSet.measured(SurfacePatch(range: range, center: center), bounds: sorted))
        }
        self.instances = instances
        self.stride = MemoryLayout<Record>.stride
        self.count = count
        self.tiers = tiers
        self.bounds = sorted
        probes = sorted.map(SurfaceObjectSet.probe)
        reaches = sorted.map(SurfaceObjectSet.reach)
        self.patches = patches
        self.owners = owners
        thresholds = tiers.map(\.minimumPixels)
        highest = sorted.map(\.extent).max() ?? 0
        self.rings = rings
        scratch = tiers.count > 1 ? UnsafeMutablePointer<UInt32>.allocate(capacity: tiers.count * count) : nil
    }

    deinit {
        scratch?.deallocate()
    }

    func record<Record>(at index: Int, as type: Record.Type) -> Record {
        instances.contents().load(fromByteOffset: index * stride, as: Record.self)
    }

    func write<Record>(_ index: Int, record: Record, bounds bound: SurfaceBounds) {
        guard store(index, record: record, bounds: bound) else { return }
        patches[owners[index]] = Self.measured(patches[owners[index]], bounds: bounds)
        revision += 1
    }

    func write<Record>(_ updates: [(index: Int, record: Record, bounds: SurfaceBounds)]) {
        var touched = Set<Int>()
        for update in updates {
            if store(update.index, record: update.record, bounds: update.bounds) {
                touched.insert(owners[update.index])
            }
        }
        guard !touched.isEmpty else { return }
        for patch in touched {
            patches[patch] = Self.measured(patches[patch], bounds: bounds)
        }
        revision += 1
    }

    func visible(in frame: GlobeFrame, focal: Float) -> [SurfaceBatch] {
        let view = SurfaceView(frame: frame, focal: focal, slack: slack(for: frame.effects))
        let buffer = rings[ring]
        ring = (ring + 1) % rings.count
        let target = buffer.contents().assumingMemoryBound(to: UInt32.self)
        let staging = scratch ?? target
        let thresholds = self.thresholds
        let capacity = count
        var counts = [Int](repeating: 0, count: thresholds.count)
        probes.withUnsafeBufferPointer { probes in
            reaches.withUnsafeBufferPointer { reaches in
                for patch in patches {
                    guard let whole = view.classify(patch) else { continue }
                    for index in patch.range {
                        let probe = probes[index]
                        let reach = reaches[index]
                        if !whole && !view.admits(probe, reach) {
                            continue
                        }
                        let tier = thresholds.count > 1 ? view.tier(probe, reach, thresholds: thresholds) : 0
                        staging[tier * capacity + counts[tier]] = UInt32(index)
                        counts[tier] += 1
                    }
                }
            }
        }
        var batches: [SurfaceBatch] = []
        var offset = 0
        for tier in counts.indices where counts[tier] > 0 {
            if scratch != nil {
                (target + offset).update(from: staging + tier * capacity, count: counts[tier])
            }
            batches.append(SurfaceBatch(tier: tier, buffer: buffer, offset: offset * MemoryLayout<UInt32>.stride, count: counts[tier]))
            offset += (counts[tier] + Self.batchAlignment - 1) / Self.batchAlignment * Self.batchAlignment
        }
        return batches
    }

    private func store<Record>(_ index: Int, record: Record, bounds bound: SurfaceBounds) -> Bool {
        guard MemoryLayout<Record>.stride == stride, bounds.indices.contains(index) else { return false }
        instances.contents().storeBytes(of: record, toByteOffset: index * stride, as: Record.self)
        let normalized = Self.normalized(bound)
        bounds[index] = normalized
        probes[index] = Self.probe(normalized)
        reaches[index] = Self.reach(normalized)
        highest = max(highest, normalized.extent)
        return true
    }

    private func slack(for effects: EffectSnapshot) -> Float {
        let stretch = effects.shape - matrix_identity_double3x3
        let squash = length(stretch[0]) + length(stretch[1]) + length(stretch[2])
        let swell = Double(highest) * max(effects.inflate - 1, 0)
        return Float(swell + abs(effects.bumpHeight) + max(-effects.dentDepth, 0) + abs(effects.rippleDisplacement) + squash * 1.1)
    }

    private static func normalized(_ bound: SurfaceBounds) -> SurfaceBounds {
        var result = bound
        let magnitude = length(bound.center)
        result.center = magnitude > 1e-9 ? bound.center / magnitude : SIMD3(0, 1, 0)
        result.radius = max(bound.radius, 0)
        result.extent = max(bound.extent, 0)
        return result
    }

    private static func probe(_ bound: SurfaceBounds) -> SIMD4<Float> {
        SIMD4(bound.center, 1 + bound.extent / 2)
    }

    private static func reach(_ bound: SurfaceBounds) -> SIMD4<Float> {
        let horizon = acos(1 / (1 + bound.extent)) + bound.radius
        return SIMD4(2 * bound.radius + bound.extent, cos(horizon), sin(horizon), bound.size)
    }

    private static func measured(_ patch: SurfacePatch, bounds: [SurfaceBounds]) -> SurfacePatch {
        var radius: Float = 0
        var extent: Float = 0
        for index in patch.range {
            let bound = bounds[index]
            radius = max(radius, acos(min(max(dot(patch.center, bound.center), -1), 1)) + bound.radius)
            extent = max(extent, bound.extent)
        }
        var result = patch
        result.radius = radius
        result.outer = acos(1 / (1 + extent)) + radius
        result.lift = 1 + extent / 2
        result.reach = 2 * radius * (1 + extent) + 1.5 * extent
        return result
    }

    private static func layout(_ bounds: [SurfaceBounds]) -> (order: [Int], ranges: [Range<Int>]) {
        let rows = Int((180 / patchDegrees).rounded(.up))
        var columns = [Int](repeating: 1, count: rows)
        var starts = [Int](repeating: 0, count: rows + 1)
        for row in 0..<rows {
            let latitude = (-90 + (Float(row) + 0.5) * patchDegrees) * .pi / 180
            columns[row] = max(Int(360 * cos(latitude) / patchDegrees), 1)
            starts[row + 1] = starts[row] + columns[row]
        }
        let keys = bounds.map { bound -> Int in
            let latitude = asin(min(max(bound.center.y, -1), 1)) * 180 / .pi
            let longitude = atan2(bound.center.x, bound.center.z) * 180 / .pi
            let row = min(max(Int((latitude + 90) / patchDegrees), 0), rows - 1)
            let column = min(max(Int((longitude + 180) / 360 * Float(columns[row])), 0), columns[row] - 1)
            return starts[row] + column
        }
        let cells = starts[rows]
        var offsets = [Int](repeating: 0, count: cells + 1)
        for key in keys {
            offsets[key + 1] += 1
        }
        for key in 0..<cells {
            offsets[key + 1] += offsets[key]
        }
        var cursor = offsets
        var order = [Int](repeating: 0, count: bounds.count)
        for (index, key) in keys.enumerated() {
            order[cursor[key]] = index
            cursor[key] += 1
        }
        var ranges: [Range<Int>] = []
        for key in 0..<cells where offsets[key + 1] > offsets[key] {
            ranges.append(offsets[key]..<offsets[key + 1])
        }
        return (order, ranges)
    }
}

private struct SurfacePatch {
    let range: Range<Int>
    let center: SIMD3<Float>
    var radius: Float = 0
    var outer: Float = 0
    var lift: Float = 1
    var reach: Float = 0
}

private struct SurfaceView {
    let eye: SIMD3<Float>
    let toward: SIMD3<Float>
    let forward: SIMD3<Float>
    let horizon: Float
    let cosine: Float
    let sine: Float
    let padding: Float
    let focal: Float
    let left: SIMD3<Float>
    let right: SIMD3<Float>
    let top: SIMD3<Float>
    let bottom: SIMD3<Float>

    init(frame: GlobeFrame, focal: Float, slack: Float) {
        let position = frame.position
        let distance = length(position)
        eye = SIMD3<Float>(position)
        toward = SIMD3<Float>(position / distance)
        forward = SIMD3<Float>(frame.forward)
        horizon = Float(acos(min(1 / distance, 1)) + acos(1 / (1 + Double(slack))))
        cosine = cos(horizon)
        sine = sin(horizon)
        padding = slack + Float(abs(frame.effects.dentDepth))
        self.focal = focal
        let lens = frame.focalLength
        let width = Double(frame.size.width)
        let height = Double(frame.size.height)
        let centerX = Double(frame.center.x)
        let centerY = Double(frame.center.y)
        let ahead = frame.forward
        let across = frame.right
        let above = frame.up
        left = SIMD3<Float>(normalize(across * lens + ahead * centerX))
        right = SIMD3<Float>(normalize(ahead * (width - centerX) - across * lens))
        top = SIMD3<Float>(normalize(ahead * centerY - above * lens))
        bottom = SIMD3<Float>(normalize(ahead * (height - centerY) + above * lens))
    }

    func classify(_ patch: SurfacePatch) -> Bool? {
        let facing = dot(patch.center, toward)
        guard facing > cos(min(horizon + patch.outer, .pi)) else { return nil }
        let anchor = patch.center * patch.lift - eye
        let reach = patch.reach + padding
        let gap = min(min(dot(left, anchor), dot(right, anchor)), min(dot(top, anchor), dot(bottom, anchor)))
        guard gap >= -reach else { return nil }
        return gap >= reach && horizon > patch.radius && facing > cos(horizon - patch.radius)
    }

    func admits(_ probe: SIMD4<Float>, _ reach: SIMD4<Float>) -> Bool {
        let direction = SIMD3(probe.x, probe.y, probe.z)
        guard dot(direction, toward) > cosine * reach.y - sine * reach.z else { return false }
        let anchor = direction * probe.w - eye
        let radius = reach.x + padding
        return dot(left, anchor) >= -radius && dot(right, anchor) >= -radius && dot(top, anchor) >= -radius && dot(bottom, anchor) >= -radius
    }

    func tier(_ probe: SIMD4<Float>, _ reach: SIMD4<Float>, thresholds: [Float]) -> Int {
        let depth = dot(SIMD3(probe.x, probe.y, probe.z) * probe.w - eye, forward)
        let span = focal * reach.w
        var choice = thresholds.count - 1
        while choice > 0 && thresholds[choice] * depth > span {
            choice -= 1
        }
        return choice
    }
}
