import Metal
import simd

struct MosaicTile {
    var site: SIMD4<Float>
    var outline: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)
    var inset: (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>)
    var land: SIMD4<Float>
    var sea: SIMD4<Float>
    var form: SIMD4<Float>
    var pose: SIMD4<Float>
    var timing: SIMD4<Float>
    var motion: SIMD4<Float>
    var shake: SIMD4<Float>
}

enum MosaicTiles {
    static let corners = 7
    static let bevelPixels: Float = 20
    private static let seed: Float = 11
    private static let snowWindow: Float = 0.04
    private static let probeReach = 0.6
    private static let window = 3

    static func build(surface: ToySurface, device: MTLDevice) -> SurfaceObjectSet? {
        let look = MosaicLook.standard
        let lattice = Lattice(tileSize: look.tileSize)
        let band = Double(lattice.band)
        let gap = Double(look.groutWidth) * band
        var tiles: [MosaicTile] = []
        var bounds: [SurfaceBounds] = []
        tiles.reserveCapacity(lattice.sites.count)
        bounds.reserveCapacity(lattice.sites.count)
        for index in lattice.sites.indices {
            guard let cell = voronoi(index, in: lattice, gap: gap) else { continue }
            let key = SIMD2<Float>(Float(lattice.rows[index]), Float(lattice.columns[index]))
            let land = isLand(cell, coast: surface.coast, share: Double(look.landShare))
            let made = tile(cell, key: key, land: land, look: look, band: band)
            tiles.append(made.record)
            bounds.append(made.bounds)
        }
        let plain = topology(rings: 2)
        let bevelled = topology(rings: 3)
        guard
            let plainIndices = indexBuffer(plain, device: device),
            let bevelledIndices = indexBuffer(bevelled, device: device)
        else { return nil }
        let tiers = [
            SurfaceTier(minimumPixels: 0, vertexCount: 2 * corners, indices: plainIndices, indexCount: plain.count),
            SurfaceTier(minimumPixels: bevelPixels, vertexCount: 3 * corners, indices: bevelledIndices, indexCount: bevelled.count),
        ]
        return SurfaceObjectSet(records: tiles, bounds: bounds, tiers: tiers, device: device)
    }

    static func hash(_ point: SIMD3<Float>) -> SIMD3<Float> {
        var p = point * SIMD3<Float>(0.1031, 0.1030, 0.0973)
        p -= p.rounded(.down)
        p += dot(p, SIMD3(p.y, p.x, p.z) + 33.33)
        let mixed = (SIMD3(p.x, p.x, p.y) + SIMD3(p.y, p.x, p.x)) * SIMD3(p.z, p.y, p.x)
        return mixed - mixed.rounded(.down)
    }

    private static func voronoi(_ index: Int, in lattice: Lattice, gap: Double) -> Cell? {
        let site = lattice.sites[index]
        let siteFrame = frame(site)
        let span = 4 * Double(lattice.band)
        var polygon = [SIMD2(-span, -span), SIMD2(span, -span), SIMD2(span, span), SIMD2(-span, span)]
        for other in lattice.candidates(around: index) {
            let neighbour = lattice.sites[other]
            let cosine = dot(site, neighbour)
            let toward = SIMD2(dot(neighbour, siteFrame.east), dot(neighbour, siteFrame.north))
            let sine = length(toward)
            guard cosine > 0.5, sine > 1e-9 else { continue }
            polygon = clipped(polygon, normal: toward / sine, offset: (1 - cosine) / sine - gap / 2)
            guard polygon.count >= 3 else { return nil }
        }
        let middle = centroid(polygon)
        let center = normalize(site + siteFrame.east * middle.x + siteFrame.north * middle.y)
        let tileFrame = frame(center)
        let recentred = polygon.map { point -> SIMD2<Double> in
            let direction = normalize(site + siteFrame.east * point.x + siteFrame.north * point.y)
            let projected = direction / dot(direction, center) - center
            return SIMD2(dot(projected, tileFrame.east), dot(projected, tileFrame.north))
        }
        let shape = reduced(recentred, to: corners)
        guard shape.count >= 3 else { return nil }
        return Cell(center: center, east: tileFrame.east, north: tileFrame.north, outline: shape)
    }

    private static func tile(_ cell: Cell, key: SIMD2<Float>, land: Bool, look: MosaicLook, band: Double) -> (record: MosaicTile, bounds: SurfaceBounds) {
        let glazes = paint(key: key, look: look)
        let tilt = hash(SIMD3(key.x, key.y, 29))
        let flip = hash(SIMD3(key.x, key.y, 53))
        let shake = hash(SIMD3(key.x, key.y, 71))
        let spread = hash(SIMD3(key.x, key.y, 89))
        let height = Double(land ? look.landHeight : look.seaHeight) * (1 + Double(look.heightJitter * (spread.x - 0.5)))
        let width = min(Double(look.bevel) * band, 0.45 * inradius(cell.outline))
        let inset = bevelled(cell.outline, width: width) ?? cell.outline.map { $0 * 0.8 }
        let drop = min(Double(look.bevelSlope) * width, 0.6 * height)
        let reach = cell.outline.map { length($0) }.max() ?? 0
        let lean = (SIMD2(tilt.x, tilt.y) - 0.5) * (2 * look.tileTilt)
        let tip: SIMD2<Float> = flip.z < 0.5 ? SIMD2(1, 0) : SIMD2(0, 1)
        let rattle = (SIMD2(shake.x, shake.y) - 0.5) * (2 * look.rattle)
        let threshold = (look.flipThreshold + look.flipSpread * flip.y) * look.recovery
        let record = MosaicTile(
            site: SIMD4(SIMD3<Float>(cell.center), Float(height)),
            outline: packed(cell.outline),
            inset: packed(inset),
            land: glazes.land,
            sea: glazes.sea,
            form: SIMD4(Float(reach), Float(drop), look.skirt, 0),
            pose: SIMD4(lowHalf: lean, highHalf: tip),
            timing: SIMD4(look.flipJitter * flip.x, look.flipTime * (0.85 + 0.3 * spread.y), threshold, snowWindow * look.recovery),
            motion: SIMD4(look.inflateSpan * .pi, look.funnel, look.pressDepth, Float(EffectTuning.mosaic.ripple.duration)),
            shake: SIMD4(rattle.x, rattle.y, look.flipLift, 0)
        )
        let bounds = SurfaceBounds(
            center: SIMD3<Float>(cell.center),
            radius: Float(atan(reach)),
            extent: Float(height + 2 * reach) + look.flipLift,
            size: Float(2 * reach)
        )
        return (record, bounds)
    }

    private static func paint(key: SIMD2<Float>, look: MosaicLook) -> (land: SIMD4<Float>, sea: SIMD4<Float>) {
        let ground = hash(SIMD3(key.x, key.y, 17))
        let rim = hash(SIMD3(key.x, key.y, 24))
        let water = hash(SIMD3(key.x, key.y, 38))
        let gold = ground.y < look.goldChance
        let earth = pick(ground.x, [(0.3, look.ochre.xyz), (0.55, look.orange.xyz), (0.8, look.olive.xyz)], last: look.lemon.xyz)
        let between = blend(look.cobalt.xyz, look.turquoise.xyz, 0.5)
        let ocean = pick(water.x, [(0.4, look.cobalt.xyz), (0.7, look.turquoise.xyz), (0.88, between)], last: look.seaWhite.xyz)
        let land = (gold ? look.gold.xyz : earth) * (0.92 + 0.16 * ground.z)
        let sea = ocean * (0.92 + 0.16 * water.z)
        return (SIMD4(land, gold ? 1 : 0), SIMD4(sea, rim.z))
    }

    private static func pick(_ value: Float, _ steps: [(limit: Float, color: SIMD3<Float>)], last: SIMD3<Float>) -> SIMD3<Float> {
        steps.first { value < $0.limit }?.color ?? last
    }

    private static func blend(_ from: SIMD3<Float>, _ to: SIMD3<Float>, _ amount: Float) -> SIMD3<Float> {
        from + (to - from) * amount
    }

    private static func isLand(_ cell: Cell, coast: TerrainGrid, share: Double) -> Bool {
        let probes = [SIMD2<Double>.zero, SIMD2<Double>.zero] + cell.outline.map { $0 * probeReach }
        let votes = probes.filter { coast.sample(cell.direction($0)) > 0 }.count
        return Double(votes) >= share * Double(probes.count)
    }

    private static func frame(_ direction: SIMD3<Double>) -> (east: SIMD3<Double>, north: SIMD3<Double>) {
        let ring = (direction.x * direction.x + direction.z * direction.z).squareRoot()
        let east = ring > 1e-5 ? SIMD3(direction.z, 0, -direction.x) / ring : SIMD3<Double>(1, 0, 0)
        return (east, cross(direction, east))
    }

    private static func clipped(_ polygon: [SIMD2<Double>], normal: SIMD2<Double>, offset: Double) -> [SIMD2<Double>] {
        var result: [SIMD2<Double>] = []
        result.reserveCapacity(polygon.count + 1)
        for index in polygon.indices {
            let current = polygon[index]
            let next = polygon[(index + 1) % polygon.count]
            let currentDepth = dot(current, normal) - offset
            let nextDepth = dot(next, normal) - offset
            let inside = currentDepth <= 0
            if inside {
                result.append(current)
            }
            if inside != (nextDepth <= 0) {
                result.append(current + (next - current) * (currentDepth / (currentDepth - nextDepth)))
            }
        }
        return result
    }

    private static func centroid(_ points: [SIMD2<Double>]) -> SIMD2<Double> {
        var area = 0.0
        var sum = SIMD2<Double>.zero
        for index in points.indices {
            let point = points[index]
            let next = points[(index + 1) % points.count]
            let weight = point.x * next.y - point.y * next.x
            area += weight
            sum += (point + next) * weight
        }
        guard abs(area) > 1e-18 else { return .zero }
        return sum / (3 * area)
    }

    private static func reduced(_ outline: [SIMD2<Double>], to limit: Int) -> [SIMD2<Double>] {
        var points: [SIMD2<Double>] = []
        for point in outline {
            if let last = points.last, length(point - last) < 1e-9 {
                continue
            }
            points.append(point)
        }
        if points.count > 3, let first = points.first, let last = points.last, length(first - last) < 1e-9 {
            points.removeLast()
        }
        while points.count > limit {
            var weakest = 0
            var smallest = Double.infinity
            for index in points.indices {
                let point = points[index]
                let before = points[(index + points.count - 1) % points.count] - point
                let after = points[(index + 1) % points.count] - point
                let area = abs(before.x * after.y - before.y * after.x)
                if area < smallest {
                    smallest = area
                    weakest = index
                }
            }
            points.remove(at: weakest)
        }
        return points
    }

    private static func inradius(_ outline: [SIMD2<Double>]) -> Double {
        var nearest = Double.infinity
        for index in outline.indices {
            let point = outline[index]
            let next = outline[(index + 1) % outline.count]
            let span = length(next - point)
            if span > 1e-12 {
                nearest = min(nearest, abs(point.x * next.y - point.y * next.x) / span)
            }
        }
        return nearest
    }

    private static func bevelled(_ outline: [SIMD2<Double>], width: Double) -> [SIMD2<Double>]? {
        let count = outline.count
        var normals: [SIMD2<Double>] = []
        var inner = outline
        for index in 0..<count {
            let from = outline[index]
            let along = outline[(index + 1) % count] - from
            let outward = SIMD2(along.y, -along.x) / max(length(along), 1e-12)
            normals.append(outward)
            inner = clipped(inner, normal: outward, offset: dot(from, outward) - width)
        }
        let merge = 0.05 * width
        var ring: [SIMD2<Double>] = []
        for point in inner {
            if let last = ring.last, length(point - last) < merge {
                continue
            }
            ring.append(point)
        }
        if ring.count > 1, let first = ring.first, let last = ring.last, length(first - last) < merge {
            ring.removeLast()
        }
        guard ring.count >= 3 else { return nil }
        return (0..<count).map { index in
            let before = normals[(index + count - 1) % count]
            let after = normals[index]
            let miter = outline[index] - (before + after) * (width / max(1 + dot(before, after), 0.2))
            return ring.min { length($0 - miter) < length($1 - miter) } ?? miter
        }
    }

    private static func packed(_ points: [SIMD2<Double>]) -> (SIMD4<Float>, SIMD4<Float>, SIMD4<Float>, SIMD4<Float>) {
        var slots = points.map { SIMD2<Float>($0) }
        while slots.count < 8 {
            slots.append(slots[slots.count - 1])
        }
        return (
            SIMD4(lowHalf: slots[0], highHalf: slots[1]),
            SIMD4(lowHalf: slots[2], highHalf: slots[3]),
            SIMD4(lowHalf: slots[4], highHalf: slots[5]),
            SIMD4(lowHalf: slots[6], highHalf: slots[7])
        )
    }

    private static func topology(rings: Int) -> [UInt16] {
        func vertex(_ ring: Int, _ corner: Int) -> UInt16 {
            UInt16(ring * corners + corner % corners)
        }
        let base = rings - 1
        var indices: [UInt16] = []
        for corner in 1..<(corners - 1) {
            indices.append(contentsOf: [vertex(0, 0), vertex(0, corner), vertex(0, corner + 1)])
        }
        for ring in 1...base {
            for corner in 0..<corners {
                indices.append(contentsOf: [vertex(ring, corner), vertex(ring, corner + 1), vertex(ring - 1, corner + 1)])
                indices.append(contentsOf: [vertex(ring, corner), vertex(ring - 1, corner + 1), vertex(ring - 1, corner)])
            }
        }
        for corner in 1..<(corners - 1) {
            indices.append(contentsOf: [vertex(base, 0), vertex(base, corner + 1), vertex(base, corner)])
        }
        return indices
    }

    private static func indexBuffer(_ indices: [UInt16], device: MTLDevice) -> MTLBuffer? {
        indices.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) }
    }

    private struct Lattice {
        let band: Float
        let counts: [Int]
        let starts: [Int]
        let sites: [SIMD3<Double>]
        let rows: [Int]
        let columns: [Int]
        let longitudes: [Double]

        init(tileSize: Float) {
            let rowCount = Int(max((180 / tileSize + 0.5).rounded(.down), 4))
            let band = Float.pi / Float(rowCount)
            var counts: [Int] = []
            var starts = [0]
            var sites: [SIMD3<Double>] = []
            var rows: [Int] = []
            var columns: [Int] = []
            var longitudes: [Double] = []
            for row in 0..<rowCount {
                let latitude = Float.pi / 2 - (Float(row) + 0.5) * band
                let count = Int(max((2 * Float(rowCount) * cos(latitude) + 0.5).rounded(.down), 1))
                counts.append(count)
                starts.append(starts[row] + count)
                for column in 0..<count {
                    let jitter = MosaicTiles.hash(SIMD3(Float(row), Float(column), MosaicTiles.seed))
                    let siteLatitude = Double(latitude + (0.35 - 0.7 * jitter.y) * band)
                    let longitude = Double(2 * Float.pi * (Float(column) + 0.15 + 0.7 * jitter.x) / Float(count) - Float.pi)
                    sites.append(SIMD3(cos(siteLatitude) * sin(longitude), sin(siteLatitude), cos(siteLatitude) * cos(longitude)))
                    rows.append(row)
                    columns.append(column)
                    longitudes.append(longitude)
                }
            }
            self.band = band
            self.counts = counts
            self.starts = starts
            self.sites = sites
            self.rows = rows
            self.columns = columns
            self.longitudes = longitudes
        }

        func candidates(around index: Int) -> [Int] {
            var result: [Int] = []
            let row = rows[index]
            for other in max(row - 2, 0)...min(row + 2, counts.count - 1) {
                let count = counts[other]
                let nominal = Int(((longitudes[index] + .pi) / (2 * .pi) * Double(count)).rounded(.down))
                let window = MosaicTiles.window
                let span = count <= 2 * window + 1 ? 0..<count : (nominal - window)..<(nominal + window + 1)
                for column in span {
                    let candidate = starts[other] + (column % count + count) % count
                    if candidate != index {
                        result.append(candidate)
                    }
                }
            }
            return result
        }
    }

    private struct Cell {
        let center: SIMD3<Double>
        let east: SIMD3<Double>
        let north: SIMD3<Double>
        let outline: [SIMD2<Double>]

        func direction(_ point: SIMD2<Double>) -> SIMD3<Double> {
            normalize(center + east * point.x + north * point.y)
        }
    }
}
