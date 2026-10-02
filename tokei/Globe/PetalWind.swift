import Foundation
import simd

struct WindStroke {
    let width: Double
    let seed: UInt32
    var last: SIMD3<Double>?
    var distance = 0.0
}

@MainActor
final class PetalWind {
    private struct Pose {
        let center: SIMD3<Float>
        let radius: Float
        let yaw: Float
        let tilt: Float
    }

    private struct Hit {
        let index: Int
        let position: Float
        let side: Float
        let half: Float
        let falloff: Float
    }

    private typealias Update = (index: Int, record: SakuraBedPetal, bounds: SurfaceBounds)

    private static let settledLean: Float = 0.32
    private static let leanTurns: Float = 7
    private static let tumble: Float = 1.2
    private static let tumbleScale: Float = 8
    private static let slowFlutter: Float = 1.4
    private static let fastFlutter: Float = 2.6
    private static let flutterTurns: Float = 23
    private static let phaseTurns: Float = 41
    private static let bedLevels = SakuraPetalBed.perCell * 4
    private static let footing: Float = 1.3
    private static let neighbourhood: Float = 2.2
    private static let shuffle: Float = 0.6

    let objects: SurfaceObjectSet
    private(set) var end = 0.0
    private let surface: ToySurface
    private let tuning: EffectTuning.Wind
    private let initial: [SakuraBedPetal]
    private var petals: [SakuraBedPetal]
    private var landings: [SIMD3<Float>]
    private var levels: [Int]
    private var grid: PetalGrid
    private var flying = Set<Int>()
    private var displaced = Set<Int>()
    private var nudged: [UInt32]
    private var seed: UInt32 = 0

    init(objects: SurfaceObjectSet, surface: ToySurface, tuning: EffectTuning.Wind) {
        let records = (0..<objects.count).map { objects.record(at: $0, as: SakuraBedPetal.self) }
        let landings = records.map { normalize(SIMD3($0.to.x, $0.to.y, $0.to.z)) }
        self.objects = objects
        self.surface = surface
        self.tuning = tuning
        initial = records
        petals = records
        self.landings = landings
        levels = [Int](repeating: Self.bedLevels - 1, count: records.count)
        grid = PetalGrid(directions: landings)
        nudged = [UInt32](repeating: 0, count: records.count)
    }

    @discardableResult
    func gust(at point: SIMD3<Double>, radius: Double, push: Double, clock: Double, instant: Bool = false) -> Bool {
        let center = SIMD3<Float>(normalize(point))
        let outline = Float(tuning.outline)
        let reach = Float(radius) * (1 + outline)
        guard reach > 0, push > 0 else { return false }
        let limit = cos(reach)
        var hits: [Int] = []
        grid.forEach(around: center, reach: reach) { index in
            if dot(landings[index], center) > limit {
                hits.append(index)
            }
        }
        guard !hits.isEmpty else { return false }
        seed &+= 1
        let east = Self.heading(at: center, angle: 0)
        let north = cross(center, east)
        var updates: [Update] = []
        updates.reserveCapacity(hits.count)
        for index in hits {
            let base = landings[index]
            let offset = base - center
            let shape = 1 + outline * Self.contour(atan2(dot(offset, north), dot(offset, east)), seed)
            let edge = Float(radius) * shape
            let distance = Self.angle(base, center)
            guard distance < edge else { continue }
            let falloff = 1 - distance / edge
            let away = Self.tangent(-center, at: base) ?? Self.heading(at: base, angle: 2 * .pi * roll(index, 0))
            let course = Self.turn(away, around: base, by: Float(tuning.veer) * (2 * roll(index, 1) - 1))
            let travel = Float(push) * shape * falloff * falloff * jitter(index, 2)
            let spin = Float(tuning.spin) * falloff * (2 * roll(index, 3) - 1)
            let target = Self.move(base, toward: course, by: travel)
            updates.append(launch(index, to: target, push: travel, spin: spin, clock: Float(clock), instant: instant))
        }
        guard !updates.isEmpty else { return false }
        objects.write(updates)
        return true
    }

    func beginStroke(width: Double, from start: SIMD3<Double>?) -> WindStroke {
        seed &+= 1
        return WindStroke(width: width, seed: seed, last: start)
    }

    @discardableResult
    func sweep(to point: SIMD3<Double>, stroke: inout WindStroke, clock: Double, instant: Bool = false) -> Bool {
        guard let last = stroke.last else {
            stroke.last = point
            return false
        }
        let step = acos(min(max(dot(last, point), -1), 1))
        guard step >= stroke.width * tuning.brush.spacing else { return false }
        let moved = brush(from: last, to: point, along: stroke, clock: Float(clock), instant: instant)
        stroke.distance += step
        stroke.last = point
        return moved
    }

    private func brush(from start: SIMD3<Double>, to finish: SIMD3<Double>, along stroke: WindStroke, clock: Float, instant: Bool) -> Bool {
        let a = SIMD3<Float>(normalize(start))
        let b = SIMD3<Float>(normalize(finish))
        let width = Float(stroke.width)
        let span = Self.angle(a, b)
        let axis = cross(a, b)
        guard width > 0, span > 1e-5, length(axis) > 1e-9 else { return false }
        let setting = tuning.brush
        let normal = normalize(axis)
        let forward = cross(normal, a)
        let middle = normalize(a + b)
        let origin = Float(stroke.distance)
        let wavelength = width * Float(setting.wavelength)
        let wobble = width * Float(setting.wobble)
        let swell = Float(setting.swell)
        let reach = span / 2 + width * (1 + swell) + wobble
        let limit = cos(reach)
        var hits: [Hit] = []
        grid.forEach(around: middle, reach: reach) { index in
            let point = landings[index]
            guard dot(point, middle) > limit else { return }
            let along = atan2(dot(point, forward), dot(point, a))
            guard along >= 0 else { return }
            let position = (origin + min(along, span)) / wavelength
            let half = width * (1 + swell * Self.wave(position, stroke.seed, 13))
            let side = asin(min(max(dot(point, normal), -1), 1)) - wobble * Self.wave(position, stroke.seed, 11)
            let beyond = max(along - span, 0)
            let gap = (side * side + beyond * beyond).squareRoot()
            if gap < half {
                hits.append(Hit(index: index, position: position, side: side, half: half, falloff: 1 - gap / half))
            }
        }
        guard !hits.isEmpty else { return false }
        seed &+= 1
        let ahead = min(span * Float(setting.ahead), width * Float(setting.aheadLimit))
        var updates: [Update] = []
        updates.reserveCapacity(hits.count)
        for hit in hits {
            guard nudged[hit.index] != stroke.seed else { continue }
            let lingers = Self.hash(hit.index, stroke.seed, 21) < Float(setting.ragged) * Self.smoothstep(0.35, 1, abs(hit.side) / hit.half)
            if lingers {
                nudged[hit.index] = stroke.seed
                guard Self.hash(hit.index, stroke.seed, 22) > 0.45 else { continue }
            }
            let share: Float = lingers ? 0.1 + 0.3 * Self.hash(hit.index, stroke.seed, 23) : 1
            let base = landings[hit.index]
            let bulge = 0.5 + 0.5 * Self.wave(hit.position * 1.7, stroke.seed, hit.side < 0 ? 31 : 33)
            let wall = hit.half * (1 + Float(setting.aside) * (bulge + roll(hit.index, 1)))
            let puff = Self.smoothstep(0.35, 0.85, Self.noise(hit.position / 1.6, stroke.seed, 35))
            let thrown = roll(hit.index, 7) < 0.45 * puff ? Float(setting.puff) * width * puff * (0.6 + 0.8 * roll(hit.index, 8)) : 0
            let sideways = max(wall - abs(hit.side), 0) * share
            let onward = (ahead * hit.falloff * hit.falloff * jitter(hit.index, 2) + thrown) * share
            let outward = Self.tangent(hit.side < 0 ? -normal : normal, at: base) ?? .zero
            let shove = outward * sideways + normalize(cross(normal, base)) * onward
            let travel = length(shove)
            guard travel > 1e-6 else { continue }
            let swirl = Float(setting.veer) * (2 * roll(hit.index, 9) - 1) + Float(setting.curl) * Self.wave(hit.position * 2.3, stroke.seed, 37)
            let course = Self.turn(shove / travel, around: base, by: swirl)
            let spin = Float(tuning.spin) * hit.falloff * (2 * roll(hit.index, 3) - 1)
            let target = Self.move(base, toward: course, by: travel)
            updates.append(launch(hit.index, to: target, push: travel, spin: spin, clock: clock, instant: instant))
        }
        guard !updates.isEmpty else { return false }
        objects.write(updates)
        return true
    }

    func commit() {
        var updates: [Update] = []
        updates.reserveCapacity(flying.count)
        for index in flying {
            let petal = petals[index]
            let rest = SakuraBedPetal(
                from: petal.to,
                to: petal.to,
                pose: SIMD4(petal.pose.y, petal.pose.y, Self.settledTilt(petal.timing.w), petal.pose.w),
                timing: SIMD4(0, 0, 0, petal.timing.w)
            )
            petals[index] = rest
            updates.append((index: index, record: rest, bounds: Self.restBounds(of: rest)))
        }
        flying.removeAll()
        end = 0
        objects.write(updates)
    }

    func reset() {
        var updates: [Update] = []
        updates.reserveCapacity(displaced.count)
        for index in displaced {
            let petal = initial[index]
            let landing = normalize(SIMD3(petal.to.x, petal.to.y, petal.to.z))
            petals[index] = petal
            landings[index] = landing
            levels[index] = Self.bedLevels - 1
            grid.move(index, to: landing)
            updates.append((index: index, record: petal, bounds: Self.restBounds(of: petal)))
        }
        displaced.removeAll()
        flying.removeAll()
        end = 0
        objects.write(updates)
    }

    private func launch(_ index: Int, to target: SIMD3<Float>, push: Float, spin: Float, clock: Float, instant: Bool) -> Update {
        let petal = petals[index]
        let size = petal.pose.w
        let random = petal.timing.w
        let now = Self.pose(of: petal, at: clock)
        let level = stackLevel(at: target, excluding: index, size: size)
        let tilt = Self.settledTilt(random)
        let ground = max(Float(surface.height(along: SIMD3<Double>(target))), 0)
        let stacked = (Float(level) + Self.shuffle * roll(index, 4)) * Float(SakuraPetalBed.stack)
        let rest: Float = 1 + ground + Float(SakuraPetalBed.lift) + stacked + Self.dip(tilt: tilt, size: size, random: random)
        let landing = SIMD4(target, rest)
        let yaw = now.yaw.remainder(dividingBy: 2 * .pi)
        let record: SakuraBedPetal
        let bounds: SurfaceBounds
        if instant {
            record = SakuraBedPetal(from: landing, to: landing, pose: SIMD4(yaw + spin, yaw + spin, tilt, size), timing: SIMD4(0, 0, 0, random))
            bounds = Self.restBounds(of: record)
            flying.remove(index)
        } else {
            let duration = Float(tuning.shortest) + Float(tuning.longest - tuning.shortest) * min(push / Float(tuning.farthest), 1).squareRoot()
            let arc = min(push * Float(tuning.lift), max(Float(tuning.ceiling) - max(now.radius, landing.w), 0))
            record = SakuraBedPetal(from: SIMD4(now.center, now.radius), to: landing, pose: SIMD4(yaw, yaw + spin, now.tilt, size), timing: SIMD4(clock, duration, arc, random))
            bounds = SurfaceBounds(
                center: target,
                radius: Self.angle(now.center, target) + size * Self.footing,
                extent: max(now.radius, landing.w) + arc - 1 + size * Self.footing,
                size: size * 2
            )
            flying.insert(index)
            end = max(end, Double(clock + duration))
        }
        petals[index] = record
        landings[index] = target
        levels[index] = level
        grid.move(index, to: target)
        displaced.insert(index)
        return (index: index, record: record, bounds: bounds)
    }

    private func stackLevel(at target: SIMD3<Float>, excluding index: Int, size: Float) -> Int {
        let reach = size * Self.neighbourhood
        let limit = cos(reach)
        var top = Self.bedLevels - 1
        grid.forEach(around: target, reach: reach) { other in
            if other != index && levels[other] > top && dot(landings[other], target) > limit {
                top = levels[other]
            }
        }
        return min(top + 1, Self.bedLevels + tuning.stack)
    }

    private func roll(_ index: Int, _ salt: UInt32) -> Float {
        Self.hash(index, seed, salt)
    }

    private func jitter(_ index: Int, _ salt: UInt32) -> Float {
        1 + Float(tuning.jitter) * (2 * roll(index, salt) - 1)
    }

    private static func hash(_ index: Int, _ seed: UInt32, _ salt: UInt32) -> Float {
        var value = (UInt32(truncatingIfNeeded: index) &* 0x9E37_79B9) ^ (seed &* 0x85EB_CA6B) ^ (salt &* 0xC2B2_AE35)
        value = (value ^ (value >> 16)) &* 0x7FEB_352D
        value = (value ^ (value >> 15)) &* 0x846C_A68B
        value ^= value >> 16
        return Float(value >> 8) / 16_777_216
    }

    private static func noise(_ position: Float, _ seed: UInt32, _ salt: UInt32) -> Float {
        let cell = position.rounded(.down)
        let t = position - cell
        let low = hash(Int(cell), seed, salt)
        let high = hash(Int(cell) + 1, seed, salt)
        return (low + (high - low) * t * t * (3 - 2 * t)) * 2 - 1
    }

    private static func wave(_ position: Float, _ seed: UInt32, _ salt: UInt32) -> Float {
        noise(position, seed, salt) * 0.7 + noise(position * 2.3 + 0.5, seed, salt + 1) * 0.3
    }

    private static func contour(_ bearing: Float, _ seed: UInt32) -> Float {
        var total: Float = 0
        var weight: Float = 0
        for order in 2...5 {
            let amplitude = (0.4 + 0.6 * hash(order, seed, 41)) / Float(order).squareRoot()
            total += amplitude * cos(Float(order) * bearing + 2 * .pi * hash(order, seed, 43))
            weight += amplitude
        }
        return total / weight
    }

    private static func smoothstep(_ low: Float, _ high: Float, _ value: Float) -> Float {
        let t = min(max((value - low) / (high - low), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private static func pose(of petal: SakuraBedPetal, at clock: Float) -> Pose {
        let airborne = petal.timing.y > 0
        let progress = airborne ? min(max((clock - petal.timing.x) / petal.timing.y, 0), 1) : 1
        let travel = 1 - (1 - progress) * (1 - progress)
        let rise = sin(Float.pi * travel)
        let from = SIMD3(petal.from.x, petal.from.y, petal.from.z)
        let to = SIMD3(petal.to.x, petal.to.y, petal.to.z)
        let gust = rise * min(max(length(to - from) * tumbleScale, 0), 1)
        let cycles = petal.timing.y * (slowFlutter + (fastFlutter - slowFlutter) * fraction(petal.timing.w * flutterTurns))
        let swing = sin(2 * Float.pi * (travel * cycles + fraction(petal.timing.w * phaseTurns)))
        let settle = airborne ? settledTilt(petal.timing.w) : petal.pose.z
        return Pose(
            center: normalize(from + (to - from) * travel),
            radius: petal.from.w + (petal.to.w - petal.from.w) * travel + petal.timing.z * rise,
            yaw: petal.pose.x + (petal.pose.y - petal.pose.x) * travel,
            tilt: petal.pose.z + (settle - petal.pose.z) * travel + gust * tumble * swing
        )
    }

    private static func settledTilt(_ random: Float) -> Float {
        let lean = fraction(random * leanTurns)
        return settledLean * lean * lean
    }

    private static func dip(tilt: Float, size: Float, random: Float) -> Float {
        let axis = 2 * Float.pi * fraction(random * SakuraPetalBed.axisTurns)
        return sin(tilt) * size * (abs(sin(axis)) + SakuraPetalBed.aspect * abs(cos(axis)))
    }

    private static func restBounds(of petal: SakuraBedPetal) -> SurfaceBounds {
        let size = petal.pose.w
        return SurfaceBounds(center: SIMD3(petal.to.x, petal.to.y, petal.to.z), radius: size * footing, extent: petal.to.w - 1 + size * footing, size: size * 2)
    }

    private static func fraction(_ value: Float) -> Float {
        value - value.rounded(.down)
    }

    private static func angle(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        atan2(length(cross(a, b)), dot(a, b))
    }

    private static func move(_ point: SIMD3<Float>, toward heading: SIMD3<Float>, by angle: Float) -> SIMD3<Float> {
        normalize(point * cos(angle) + heading * sin(angle))
    }

    private static func turn(_ heading: SIMD3<Float>, around point: SIMD3<Float>, by angle: Float) -> SIMD3<Float> {
        heading * cos(angle) + cross(point, heading) * sin(angle)
    }

    private static func tangent(_ vector: SIMD3<Float>, at point: SIMD3<Float>) -> SIMD3<Float>? {
        let flat = vector - point * dot(vector, point)
        let size = length(flat)
        return size > 1e-6 ? flat / size : nil
    }

    private static func heading(at point: SIMD3<Float>, angle: Float) -> SIMD3<Float> {
        let helper: SIMD3<Float> = abs(point.y) < 0.9 ? SIMD3(0, 1, 0) : SIMD3(1, 0, 0)
        let east = normalize(cross(helper, point))
        return east * cos(angle) + cross(point, east) * sin(angle)
    }
}

private struct PetalGrid {
    static let degrees: Float = 2

    private let columns: [Int]
    private let starts: [Int]
    private var cells: [[Int32]]
    private var homes: [Int]

    init(directions: [SIMD3<Float>]) {
        let rows = Int(180 / Self.degrees)
        var columns = [Int](repeating: 1, count: rows)
        var starts = [Int](repeating: 0, count: rows + 1)
        for band in 0..<rows {
            let latitude = (-90 + (Float(band) + 0.5) * Self.degrees) * .pi / 180
            columns[band] = max(Int(360 * cos(latitude) / Self.degrees), 1)
            starts[band + 1] = starts[band] + columns[band]
        }
        self.columns = columns
        self.starts = starts
        cells = [[Int32]](repeating: [], count: starts[rows])
        homes = [Int](repeating: 0, count: directions.count)
        for (index, direction) in directions.enumerated() {
            let cell = key(of: direction)
            cells[cell].append(Int32(index))
            homes[index] = cell
        }
    }

    mutating func move(_ index: Int, to direction: SIMD3<Float>) {
        let cell = key(of: direction)
        let home = homes[index]
        guard cell != home else { return }
        if let slot = cells[home].firstIndex(of: Int32(index)) {
            cells[home].swapAt(slot, cells[home].count - 1)
            cells[home].removeLast()
        }
        cells[cell].append(Int32(index))
        homes[index] = cell
    }

    func forEach(around center: SIMD3<Float>, reach: Float, _ body: (Int) -> Void) {
        let latitude = asin(min(max(center.y, -1), 1))
        let longitude = atan2(center.x, center.z)
        let ring = cos(latitude)
        let whole = sin(reach) >= ring
        let spread = whole ? Float.pi : asin(sin(reach) / ring)
        for band in row(at: latitude - reach)...row(at: latitude + reach) {
            let count = columns[band]
            let first = column(at: longitude - spread, count: count) - 1
            let last = column(at: longitude + spread, count: count) + 1
            let width = whole ? count : min(last - first + 1, count)
            let start = whole ? 0 : first
            for step in 0..<width {
                for index in cells[starts[band] + ((start + step) % count + count) % count] {
                    body(Int(index))
                }
            }
        }
    }

    private func key(of direction: SIMD3<Float>) -> Int {
        let band = row(at: asin(min(max(direction.y, -1), 1)))
        let count = columns[band]
        return starts[band] + min(max(column(at: atan2(direction.x, direction.z), count: count), 0), count - 1)
    }

    private func row(at latitude: Float) -> Int {
        min(max(Int(((latitude * 180 / .pi + 90) / Self.degrees).rounded(.down)), 0), columns.count - 1)
    }

    private func column(at longitude: Float, count: Int) -> Int {
        Int(((longitude / (2 * .pi) + 0.5) * Float(count)).rounded(.down))
    }
}
