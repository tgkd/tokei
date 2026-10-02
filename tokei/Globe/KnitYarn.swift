import Metal
import simd

struct KnitYarnPiece {
    var span: SIMD4<Float>
    var course: SIMD4<Float>
    var yarn: SIMD4<Float>
    var color: SIMD4<Float>
}

enum KnitYarn {
    static let tubes: [(along: Int, around: Int)] = [(12, 4), (16, 6), (24, 8), (32, 10)]
    static let loop = SIMD4<Double>(0.03, 0.25, 0.15, 0.78)
    private static let snowflake = [2, 1, 2]
    private static let peerie = [1, 3, 1]
    private static let diamond = [1, 2, 1]

    static func build(surface: ToySurface, device: MTLDevice) -> SurfaceObjectSet? {
        let look = KnitLook.standard
        var pieces: [KnitYarnPiece] = []
        var bounds: [SurfaceBounds] = []
        pieces.reserveCapacity(7_000)
        bounds.reserveCapacity(7_000)
        stitches(look: look, coast: surface.coast, pieces: &pieces, bounds: &bounds)
        lining(pole: 1, look: look, coast: surface.coast, pieces: &pieces, bounds: &bounds)
        lining(pole: -1, look: look, coast: surface.coast, pieces: &pieces, bounds: &bounds)
        pompom(at: SIMD3(0, 1, 0), look: look, seed: 0x6B6E_6974_706F_6D31, pieces: &pieces, bounds: &bounds)
        pompom(at: SIMD3(0, -1, 0), look: look, seed: 0x6B6E_6974_706F_6D32, pieces: &pieces, bounds: &bounds)
        cityPompom(look: look, pieces: &pieces, bounds: &bounds)
        let thresholds = [0, look.detailPixels, look.finePixels, look.closePixels]
        var tiers: [SurfaceTier] = []
        for (index, tube) in tubes.enumerated() {
            guard let tier = surfaceTier(tube, minimumPixels: thresholds[index], device: device) else { return nil }
            tiers.append(tier)
        }
        return SurfaceObjectSet(records: pieces, bounds: bounds, tiers: tiers, device: device)
    }

    private static func goreColumns(latitude: Double, look: KnitLook) -> Int {
        let narrowest = min(abs(latitude) + loop.w * Double(look.rowHeight), 90)
        let room = 180 / Double(look.sectors) * cos(narrowest * .pi / 180) / Double(look.stitchWidth)
        return max(Int(room.rounded(.down)), 0)
    }

    private struct Course {
        let row: Int
        let latitude: Double
        let columns: Int
        let seam: Bool
        let split: Bool
    }

    private static func courses(_ look: KnitLook) -> [Course] {
        let height = Double(look.rowHeight)
        let halfGore = 180 / Double(look.sectors)
        let width = Double(look.stitchWidth)
        var courses: [Course] = []
        for row in 0..<Int((180 / height).rounded(.up)) {
            let latitude = (Double(row) + 0.5) * height - 90
            guard 90 - abs(latitude) > loop.w * height else { continue }
            let columns = goreColumns(latitude: latitude, look: look)
            let gap = 2 * (halfGore * cos(latitude * .pi / 180) - Double(columns) * width)
            let seam = columns == 0 || gap >= Double(look.seamMinimum) * width
            courses.append(Course(row: row, latitude: latitude, columns: columns, seam: seam, split: gap >= Double(look.seamSplit) * width))
        }
        return courses
    }

    private static func stitches(look: KnitLook, coast: TerrainGrid, pieces: inout [KnitYarnPiece], bounds: inout [SurfaceBounds]) {
        let height = Double(look.rowHeight) * .pi / 180
        let width = Double(look.stitchWidth) * .pi / 180
        let depth = Double(look.yarnDepth) * height
        let radius = Double(look.yarnRadius) * height
        let lift = depth + radius * Double(1 - look.yarnSink)
        let crest = lift + depth + radius
        let gore = 2 * Double.pi / Double(look.sectors)
        let stretch = look.stretch / look.pressDepth
        for course in courses(look) {
            let latitude = course.latitude * .pi / 180
            let profile = SIMD4<Float>(Float(latitude - loop.z * height), Float(height), Float(depth), Float(lift))
            var spans: [(span: SIMD4<Double>, column: Int)] = []
            for part in 0..<Int(look.sectors) {
                let middle = -Double.pi + (Double(part) + 0.5) * gore
                for side in [-1.0, 1.0] {
                    for column in 0..<course.columns {
                        if column == course.columns - 1 && !course.seam {
                            let inner = Double(column) * width
                            spans.append((span: SIMD4(middle + side * gore / 4, side * inner / 2, -inner, gore / 2), column: column))
                        } else {
                            spans.append((span: SIMD4(middle, side * (Double(column) + 0.5) * width, width, 0), column: column))
                        }
                    }
                }
                let inner = Double(course.columns) * width
                if course.seam && course.split {
                    spans.append((span: SIMD4(middle + gore / 4, inner / 2, -inner, gore / 2), column: course.columns))
                    spans.append((span: SIMD4(middle + gore * 3 / 4, -inner / 2, -inner, gore / 2), column: course.columns))
                } else if course.seam {
                    spans.append((span: SIMD4(middle + gore / 2, 0, -2 * inner, gore), column: course.columns))
                }
            }
            for (index, entry) in spans.enumerated() {
                let span = entry.span
                let center = GeoPoint(latitude: course.latitude, longitude: (span.x + span.y / cos(latitude)) * 180 / .pi).unitVector
                let color = yarnColor(row: course.row, column: entry.column, land: coast.sample(center) > 0, look: look)
                let piece = KnitYarnPiece(
                    span: SIMD4<Float>(span),
                    course: profile,
                    yarn: SIMD4(Float(radius), 0, Float(random(course.row, index, entry.column)), stretch),
                    color: SIMD4(color, 0)
                )
                pieces.append(piece)
                bounds.append(measured(piece, center: center, extent: crest, size: max(height, span.z + span.w * cos(latitude))))
            }
        }
    }

    private static func lining(pole: Double, look: KnitLook, coast: TerrainGrid, pieces: inout [KnitYarnPiece], bounds: inout [SurfaceBounds]) {
        let height = Double(look.rowHeight) * .pi / 180
        let radius = Double(look.yarnRadius) * height
        let lift = radius * Double(1 - look.yarnSink)
        let gores = Int(look.sectors)
        let gore = 2 * Double.pi / Double(gores)
        let reach = Double(look.liningReach) * .pi / 180
        let shade = look.backingShade / look.creaseShade
        var colatitude = Double(look.pompomRadius) * .pi / 180 * 0.6
        var ring = 0
        while colatitude <= reach {
            let latitude = pole * (.pi / 2 - colatitude)
            for part in 0..<gores {
                let middle = -Double.pi + (Double(part) + 0.5) * gore
                let center = GeoPoint(latitude: latitude * 180 / .pi, longitude: middle * 180 / .pi).unitVector
                let base = coast.sample(center) > 0 ? look.oatmeal.xyz : look.indigo.xyz
                let piece = KnitYarnPiece(
                    span: SIMD4(Float(middle), 0, 0, Float(gore)),
                    course: SIMD4(Float(latitude), 0, 0, Float(lift)),
                    yarn: SIMD4(Float(radius), 2, Float(random(ring, part, pole > 0 ? 1 : 2)), 0),
                    color: SIMD4(base * shade, 0)
                )
                pieces.append(piece)
                bounds.append(measured(piece, center: center, extent: lift + radius, size: height))
            }
            colatitude += 1.9 * radius
            ring += 1
        }
    }

    private static func yarnColor(row: Int, column: Int, land: Bool, look: KnitLook) -> SIMD3<Float> {
        let wave = max(Int(look.waveRows), 1)
        let sea = row % wave == wave - 1 ? blend(look.indigo.xyz, look.oatmeal.xyz, 0.25) : look.indigo.xyz
        guard land else { return sea }
        let band = max(Int(look.motifBand), 1)
        let line = row % band
        guard (row / band) % 2 == 1, line < snowflake.count else { return look.oatmeal.xyz }
        let middle = abs((Double(row - line + 1) + 0.5) * Double(look.rowHeight) - 90)
        let shift = column % max(Int(look.motifPeriod), 1)
        let bits: Int
        let motif: SIMD3<Float>
        if middle > 60 {
            bits = snowflake[line] >> shift
            motif = look.forest.xyz
        } else if middle > 23 {
            bits = peerie[line] >> shift
            motif = look.rust.xyz
        } else {
            bits = diamond[line] >> shift
            motif = look.mustard.xyz
        }
        return bits & 1 == 1 ? motif : look.oatmeal.xyz
    }

    private static func pompom(at pole: SIMD3<Double>, look: KnitLook, seed: UInt64, pieces: inout [KnitYarnPiece], bounds: inout [SurfaceBounds]) {
        let size = Double(look.pompomRadius) * .pi / 180
        let center = pole * (1 + look.yarnTop + Double(look.pompomRise) * size)
        let fiber = Double(look.pompomFiber) * size
        let squash = Double(look.pompomSquash)
        let count = max(Int(look.pompomStrands), 1)
        let golden = Double.pi * (3 - 5.0.squareRoot())
        var stream = Stream(seed: seed)
        for index in 0..<count {
            let rise = 1 - 2 * (Double(index) + 0.5) / Double(count)
            let ring = (1 - rise * rise).squareRoot()
            let turn = Double(index) * golden
            let jitter = SIMD3(stream.next() - 0.5, stream.next() - 0.5, stream.next() - 0.5) * 0.35
            let spoke = normalize(SIMD3(ring * cos(turn), rise * pole.y, ring * sin(turn)) + jitter)
            let reach = size * (0.82 + 0.3 * stream.next())
            let bend = reach * 0.2 * (stream.next() - 0.5)
            let width = fiber * (0.8 + 0.4 * stream.next())
            let tone = Float(stream.next())
            let twist = Float(stream.next())
            let upward = dot(spoke, pole)
            guard upward > -0.45 else { continue }
            let shaped = spoke + pole * (upward * (squash - 1))
            let root = center + shaped * (reach * 0.12)
            let tip = center + shaped * reach
            let shade = blend(look.cream.xyz, look.oatmeal.xyz, 0.4 * tone)
            pieces.append(KnitYarnPiece(
                span: SIMD4(SIMD3<Float>(root), Float(bend)),
                course: SIMD4(SIMD3<Float>(tip), 0),
                yarn: SIMD4(Float(width), 1, twist, 0),
                color: SIMD4(shade, 0)
            ))
            let middle = normalize(root + tip)
            let spread = max(separation(middle, root), separation(middle, tip)) + width + abs(bend)
            let extent = max(length(root), length(tip)) - 1 + width + abs(bend)
            bounds.append(SurfaceBounds(center: SIMD3<Float>(middle), radius: Float(spread), extent: Float(extent), size: Float(reach * 0.5)))
        }
    }

    private static func cityPompom(look: KnitLook, pieces: inout [KnitYarnPiece], bounds: inout [SurfaceBounds]) {
        let size = Double(look.cityRadius) * .pi / 180
        let height = look.yarnTop + Double(look.cityRise) * size
        let gate = Float(cos(Double(look.cityGate) * .pi / 180))
        let nearest = acos(1 / (OrbitCamera.minDistance * 0.8))
        let farthest = acos(1 / (OrbitCamera.maxDistance * 1.2))
        let pools: [(center: SIMD3<Float>, radius: Float, gate: Float)] = [
            (center: SIMD3(0, 1, 0), radius: Float(Double.pi - (nearest + farthest) / 2), gate: -gate),
            (center: SIMD3(0, -1, 0), radius: 0.15, gate: gate),
        ]
        let popHeight = Float(EffectTuning.knit.pop.height)
        let count = max(Int(look.cityStrands), 1)
        let golden = Double.pi * (3 - 5.0.squareRoot())
        var stream = Stream(seed: 0x6B6E_6974_6369_7479)
        var strands: [KnitYarnPiece] = []
        for index in 0..<count {
            let rise = 1 - 2 * (Double(index) + 0.5) / Double(count)
            let ring = (1 - rise * rise).squareRoot()
            let turn = Double(index) * golden
            let jitter = SIMD3(stream.next() - 0.5, stream.next() - 0.5, stream.next() - 0.5) * 0.35
            let spoke = normalize(SIMD3(ring * cos(turn), rise, ring * sin(turn)) + jitter)
            let reach = 0.8 + 0.25 * stream.next()
            let bend = 0.2 * (stream.next() - 0.5)
            let width = Double(look.cityFiber) * (0.8 + 0.4 * stream.next())
            let tone = Float(stream.next())
            let twist = Float(stream.next())
            guard spoke.y > -0.4 else { continue }
            strands.append(KnitYarnPiece(
                span: SIMD4(SIMD3<Float>(spoke), Float(bend)),
                course: SIMD4(Float(reach), Float(width), look.citySquash, Float(height)),
                yarn: SIMD4(Float(size), 3, twist, popHeight),
                color: SIMD4(blend(look.mustard.xyz, look.knot.xyz, 0.45 * tone), 0)
            ))
        }
        for pool in pools {
            for strand in strands {
                var piece = strand
                piece.color.w = pool.gate
                pieces.append(piece)
                bounds.append(SurfaceBounds(center: pool.center, radius: pool.radius, extent: 0, size: Float(size * 0.4)))
            }
        }
    }

    private static func measured(_ piece: KnitYarnPiece, center: SIMD3<Double>, extent: Double, size: Double) -> SurfaceBounds {
        var reach = 0.0
        for step in 0...24 {
            let t = Double.pi * (Double(step) / 12 - 1)
            reach = max(reach, separation(center, point(on: piece, at: t)))
        }
        return SurfaceBounds(center: SIMD3<Float>(center), radius: Float(reach + 1.1 * Double(piece.yarn.x)), extent: Float(extent), size: Float(size))
    }

    private static func point(on piece: KnitYarnPiece, at t: Double) -> SIMD3<Double> {
        let span = SIMD4<Double>(piece.span)
        let course = SIMD4<Double>(piece.course)
        let wiggle = piece.yarn.y > 1.5 ? 0.0 : 1.0
        let shape = t / (2 * .pi) + wiggle * (loop.x * sin(t) + loop.y * sin(2 * t))
        let latitude = course.x + course.y * (loop.z + loop.w * cos(t))
        let secant = 1 / cos(latitude)
        let longitude = span.x + span.y * secant + shape * (span.w + span.z * secant)
        return GeoPoint(latitude: latitude * 180 / .pi, longitude: longitude * 180 / .pi).unitVector
    }

    private static func surfaceTier(_ tube: (along: Int, around: Int), minimumPixels: Float, device: MTLDevice) -> SurfaceTier? {
        let ring = tube.around + 1
        var indices: [UInt16] = []
        indices.reserveCapacity(tube.along * tube.around * 6)
        for step in 0..<tube.along {
            for turn in 0..<tube.around {
                let corner = UInt16(step * ring + turn)
                let ahead = corner + UInt16(ring)
                indices.append(contentsOf: [corner, corner + 1, ahead + 1, corner, ahead + 1, ahead])
            }
        }
        guard let buffer = indices.withUnsafeBytes({ device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) }) else { return nil }
        return SurfaceTier(minimumPixels: minimumPixels, vertexCount: (tube.along + 1) * ring, indices: buffer, indexCount: indices.count, primitive: .triangle)
    }

    private static func blend(_ from: SIMD3<Float>, _ to: SIMD3<Float>, _ amount: Float) -> SIMD3<Float> {
        from + (to - from) * amount
    }

    private static func separation(_ first: SIMD3<Double>, _ second: SIMD3<Double>) -> Double {
        acos(min(max(dot(first, normalize(second)), -1), 1))
    }

    private static func random(_ first: Int, _ second: Int, _ third: Int) -> Double {
        var stream = Stream(seed: (UInt64(truncatingIfNeeded: first) &* 0x9E37_79B9_7F4A_7C15) ^ (UInt64(truncatingIfNeeded: second) &* 0xC2B2_AE3D_27D4_EB4F) ^ (UInt64(truncatingIfNeeded: third) &* 0x1656_67B1_9E37_79F9))
        return stream.next()
    }

    private struct Stream {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func next() -> Double {
            state &+= 0x9E37_79B9_7F4A_7C15
            var mixed = state
            mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
            mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
            mixed ^= mixed >> 31
            return Double(mixed >> 11) / 9_007_199_254_740_992
        }
    }
}
