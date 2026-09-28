import Accelerate
import Foundation
import simd

struct ToySurface {
    static let deepestLevel = 6
    static let grids = [4, 8, 16]
    static let tolerance: Double = 0.6
    static let placement: Double = 1.5

    let coast: TerrainGrid
    let lift: TerrainGrid
    let profile: [SIMD4<Float>]
    let crest: Double
    private let tree: TerrainTree
    private let bends: [RangeTable]
    private let detail: [Float]
    private let coarseDetail: [Float]
    private let roughest: Float

    init(coast: TerrainGrid, lift: TerrainGrid, liftHeights: [Float], profile: TerrainProfile?, tree: TerrainTree) {
        let heights = profile?.heights ?? [Float](repeating: 0, count: TerrainProfile.count)
        let relief = profile?.relief ?? [Float](repeating: 0, count: TerrainProfile.count)
        let count = heights.count
        let footprint = 360 / Double(ToyMesh.reliefWidth)
        var samples = [SIMD4<Float>](repeating: .zero, count: count)
        var index = 0
        while index < count {
            let distance = TerrainProfile.start + Double(index) * TerrainProfile.step
            let rise = Self.interpolate(heights, distance + footprint / 2) - Self.interpolate(heights, distance - footprint / 2)
            samples[index] = SIMD4(heights[index], Float(rise / footprint), relief[index], 0)
            index += 1
        }
        let detail = Self.detail(liftHeights, width: lift.width, height: lift.height)
        let coarseDetail = Self.coarsened(detail)
        self.coast = coast
        self.lift = lift
        self.profile = samples
        self.tree = tree
        var liftCrest: Float = 0
        vDSP_maxv(liftHeights, 1, &liftCrest, vDSP_Length(liftHeights.count))
        crest = Double(heights.max() ?? 0) + Double(liftCrest)
        bends = (-2...Self.deepestLevel).map { Self.bends(heights, level: $0) }
        self.detail = detail
        self.coarseDetail = coarseDetail
        roughest = detail.max() ?? 0
    }

    func height(along direction: SIMD3<Double>) -> Double {
        profileHeight(coast.sample(direction)) + lift.sample(direction)
    }

    func radius(along direction: SIMD3<Double>, in frame: GlobeFrame) -> Double {
        let unit = normalize(direction)
        let view = TerrainView(frame: frame, crest: crest)
        let place = TerrainTree.faceCoordinates(unit)
        var node = TerrainNode.roots[place.face]
        var choice = judge(node, view: view)
        while choice == nil {
            node = node.child(containing: place.a, place.b)
            choice = judge(node, view: view)
        }
        let grid = Self.grids[choice ?? Self.grids.count - 1]
        let gridI = ((place.a + 1) / node.size - Double(node.column)) * Double(grid)
        let gridJ = ((place.b + 1) / node.size - Double(node.row)) * Double(grid)
        let i = min(max(Int(floor(gridI)), 0), grid - 1)
        let j = min(max(Int(floor(gridJ)), 0), grid - 1)
        let p00 = point(node, i, j, grid: grid)
        let p10 = point(node, i + 1, j, grid: grid)
        let p01 = point(node, i, j + 1, grid: grid)
        let p11 = point(node, i + 1, j + 1, grid: grid)
        let first = Self.radialHit(unit, p00, p10, p11)
        let second = Self.radialHit(unit, p00, p11, p01)
        if first.inside && !second.inside {
            return first.radius
        }
        if second.inside && !first.inside {
            return second.radius
        }
        return gridI - Double(i) >= gridJ - Double(j) ? first.radius : second.radius
    }

    func nodes(in frame: GlobeFrame) -> [[UInt32]] {
        let view = TerrainView(frame: frame, crest: crest)
        var selected = [[UInt32]](repeating: [], count: Self.grids.count)
        var pending = TerrainNode.roots
        while let node = pending.popLast() {
            guard view.sees(node, center: tree.entry(node)) else { continue }
            if let grid = judge(node, view: view) {
                selected[grid].append(node.packed)
            } else {
                pending.append(node.child(0))
                pending.append(node.child(1))
                pending.append(node.child(2))
                pending.append(node.child(3))
            }
        }
        return selected
    }

    private func judge(_ node: TerrainNode, view: TerrainView) -> Int? {
        let entry = tree.entry(node)
        let scale = view.scale(node, center: entry)
        let obliquity = view.obliquity(node, center: entry)
        let distance = Double(entry.w)
        let reach = node.radius * 180 / .pi * 1.1 + 0.02
        let last = TerrainProfile.count - 1
        let lower = ((distance - reach - TerrainProfile.start) / TerrainProfile.step).rounded(.down)
        let upper = ((distance + reach - TerrainProfile.start) / TerrainProfile.step).rounded(.up)
        let touches = upper >= 0 && lower <= Double(last)
        let roughness = Double(roughness(node))
        func error(grid: Int, coarseness: Int) -> Double {
            let cell = node.cell(grid: grid)
            var bend = (view.curvature + roughness) * cell * cell / 8
            if touches {
                let table = bends[node.level - coarseness + 2]
                bend += Double(table.maximum(Int(max(lower, 0)), Int(min(upper, Double(last))))) * view.inflate
            }
            let lift = bend * obliquity / Self.tolerance
            let drift = 0.75 * cell / Self.placement
            return scale * min(lift, drift)
        }
        if node.level < Self.deepestLevel && error(grid: 16, coarseness: 0) > 1 {
            return nil
        }
        if error(grid: 4, coarseness: 2) <= 1 {
            return 0
        }
        if error(grid: 8, coarseness: 1) <= 1 {
            return 1
        }
        return 2
    }

    private func roughness(_ node: TerrainNode) -> Float {
        let cell = tree.detailCell(node)
        if node.level >= 5 {
            return detail[cell]
        }
        if node.level >= 3 {
            let columns = TerrainTree.detailWidth
            return coarseDetail[(cell / columns / 4) * (columns / 4) + (cell % columns) / 4]
        }
        return roughest
    }

    private func profileHeight(_ distance: Double) -> Double {
        let position = min(max((distance - TerrainProfile.start) / TerrainProfile.step, 0), Double(TerrainProfile.count - 1))
        let index = Int(position)
        let next = min(index + 1, TerrainProfile.count - 1)
        let fraction = position - Double(index)
        return Double(profile[index].x) * (1 - fraction) + Double(profile[next].x) * fraction
    }

    private static func interpolate(_ heights: [Float], _ distance: Double) -> Double {
        let position = min(max((distance - TerrainProfile.start) / TerrainProfile.step, 0), Double(heights.count - 1))
        let index = Int(position)
        let next = min(index + 1, heights.count - 1)
        let fraction = position - Double(index)
        return Double(heights[index]) * (1 - fraction) + Double(heights[next]) * fraction
    }

    private func point(_ node: TerrainNode, _ i: Int, _ j: Int, grid: Int) -> SIMD3<Double> {
        let place = node.point(i, j, grid: grid)
        let direction = TerrainTree.direction(face: node.face, a: place.a, b: place.b)
        return direction * (1 + height(along: direction))
    }

    private static func radialHit(_ d: SIMD3<Double>, _ a: SIMD3<Double>, _ b: SIMD3<Double>, _ c: SIMD3<Double>) -> (radius: Double, inside: Bool) {
        let normal = cross(b - a, c - a)
        let denominator = dot(normal, d)
        guard abs(denominator) > 1e-12 else { return (dot(a, d), false) }
        let radius = dot(normal, a) / denominator
        let hit = d * radius
        let tolerance = -1e-9 * dot(normal, normal)
        let inside = dot(cross(b - a, hit - a), normal) >= tolerance
            && dot(cross(c - b, hit - b), normal) >= tolerance
            && dot(cross(a - c, hit - c), normal) >= tolerance
        return (radius, inside)
    }

    private static func bends(_ heights: [Float], level: Int) -> RangeTable {
        let count = heights.count
        let span = 1.15 * 2 / pow(2, Double(level)) * 45 / 16 * 2.0.squareRoot()
        func height(_ distance: Double) -> Double {
            interpolate(heights, distance)
        }
        var deviations = [Float](repeating: 0, count: count)
        var index = 0
        while index < count {
            let distance = TerrainProfile.start + Double(index) * TerrainProfile.step
            let chord = (height(distance - span / 2) + height(distance + span / 2)) / 2
            deviations[index] = Float(abs(height(distance) - chord))
            index += 1
        }
        return RangeTable(deviations)
    }

    private static func coarsened(_ detail: [Float]) -> [Float] {
        let columns = TerrainTree.detailWidth / 4
        let rows = TerrainTree.detailHeight / 4
        var cells = [Float](repeating: 0, count: columns * rows)
        var index = 0
        while index < detail.count {
            let row = index / TerrainTree.detailWidth / 4
            let column = (index % TerrainTree.detailWidth) / 4
            cells[row * columns + column] = max(cells[row * columns + column], detail[index])
            index += 1
        }
        return dilated(cells, columns: columns, rows: rows)
    }

    private static func dilated(_ cells: [Float], columns: Int, rows: Int) -> [Float] {
        var result = cells
        var row = 0
        while row < rows {
            var column = 0
            while column < columns {
                var peak: Float = 0
                var dy = -1
                while dy <= 1 {
                    let y = min(max(row + dy, 0), rows - 1)
                    var dx = -1
                    while dx <= 1 {
                        peak = max(peak, cells[y * columns + (column + dx + columns) % columns])
                        dx += 1
                    }
                    dy += 1
                }
                result[row * columns + column] = peak
                column += 1
            }
            row += 1
        }
        return result
    }

    private static func detail(_ heights: [Float], width: Int, height: Int) -> [Float] {
        let columns = TerrainTree.detailWidth
        let rows = TerrainTree.detailHeight
        var cells = [Float](repeating: 0, count: columns * rows)
        let rowStep = Double.pi / Double(height)
        let columnStep = 2 * Double.pi / Double(width)
        heights.withUnsafeBufferPointer { heights in
            cells.withUnsafeMutableBufferPointer { cells in
                let values = heights.baseAddress!
                var row = 1
                while row < height - 1 {
                    let latitude = (0.5 - (Double(row) + 0.5) / Double(height)) * .pi
                    let across = max(cos(latitude), 0.1) * columnStep
                    let target = (row * rows / height) * columns
                    var column = 0
                    while column < width {
                        let index = row * width + column
                        let east = values[row * width + (column + 1) % width]
                        let west = values[row * width + (column + width - 1) % width]
                        let center = values[index]
                        let horizontal = abs(east - 2 * center + west)
                        let vertical = abs(values[index - width] - 2 * center + values[index + width])
                        let bend = max(Double(horizontal) / (across * across), Double(vertical) / (rowStep * rowStep))
                        let cell = target + column * columns / width
                        if Float(bend) > cells[cell] {
                            cells[cell] = Float(bend)
                        }
                        column += 1
                    }
                    row += 1
                }
            }
        }
        return dilated(cells, columns: columns, rows: rows)
    }
}

private struct TerrainView {
    let focal: Double
    let curvature: Double
    let inflate: Double
    let crest: Double
    private let eyeX: Double
    private let eyeY: Double
    private let eyeZ: Double
    private let eyeDistance: Double
    private let horizon: Double
    private let planes: [(x: Double, y: Double, z: Double)]

    init(frame: GlobeFrame, crest: Double) {
        let effects = frame.effects
        let rippleNumber = 2 * .pi / max(effects.rippleWavelength, 1e-3)
        let bend = abs(effects.bumpHeight) / (effects.bumpRadius * effects.bumpRadius)
            + abs(effects.dentDepth) / (effects.dentRadius * effects.dentRadius)
            + abs(effects.rippleDisplacement) * rippleNumber * rippleNumber
        let stretch = effects.shape - matrix_identity_double3x3
        let squash = length(stretch[0]) + length(stretch[1]) + length(stretch[2])
        let lifted = crest * max(effects.inflate, 1) + abs(effects.bumpHeight) + squash * 1.1
        let eye = frame.position
        eyeX = eye.x
        eyeY = eye.y
        eyeZ = eye.z
        eyeDistance = length(eye)
        focal = frame.focalLength
        curvature = 1 + bend
        inflate = max(effects.inflate, 1)
        self.crest = lifted
        horizon = acos(min(1 / eyeDistance, 1)) + acos(1 / (1 + lifted))
        let width = Double(frame.size.width)
        let height = Double(frame.size.height)
        let center = SIMD2(Double(frame.center.x), Double(frame.center.y))
        let forward = frame.forward
        let right = frame.right
        let up = frame.up
        planes = [
            normalize(right * focal + forward * center.x),
            normalize(forward * (width - center.x) - right * focal),
            normalize(forward * center.y - up * focal),
            normalize(forward * (height - center.y) + up * focal),
        ].map { ($0.x, $0.y, $0.z) }
    }

    func scale(_ node: TerrainNode, center: SIMD4<Float>) -> Double {
        let lift = 1 + crest / 2
        let dx = Double(center.x) * lift - eyeX
        let dy = Double(center.y) * lift - eyeY
        let dz = Double(center.z) * lift - eyeZ
        let reach = node.radius * (1 + crest) + crest / 2
        return focal / max((dx * dx + dy * dy + dz * dz).squareRoot() - reach, 0.02)
    }

    func obliquity(_ node: TerrainNode, center: SIMD4<Float>) -> Double {
        let x = Double(center.x)
        let y = Double(center.y)
        let z = Double(center.z)
        let dx = x - eyeX
        let dy = y - eyeY
        let dz = z - eyeZ
        let cx = y * dz - z * dy
        let cy = z * dx - x * dz
        let cz = x * dy - y * dx
        let sine = ((cx * cx + cy * cy + cz * cz) / (dx * dx + dy * dy + dz * dz)).squareRoot()
        return min(sine + 2 * node.radius, 1)
    }

    func sees(_ node: TerrainNode, center: SIMD4<Float>) -> Bool {
        let x = Double(center.x)
        let y = Double(center.y)
        let z = Double(center.z)
        let reach = min(horizon + node.radius, .pi)
        guard (x * eyeX + y * eyeY + z * eyeZ) / eyeDistance > cos(reach) else { return false }
        let lift = 1 + crest / 2
        let dx = x * lift - eyeX
        let dy = y * lift - eyeY
        let dz = z * lift - eyeZ
        let radius = node.radius * (1 + crest) + crest / 2
        for plane in planes where plane.x * dx + plane.y * dy + plane.z * dz < -radius {
            return false
        }
        return true
    }
}

private struct RangeTable {
    private let values: [Float]
    private let count: Int

    init(_ source: [Float]) {
        var values = source
        var span = 1
        var offset = 0
        while span * 2 <= source.count {
            let width = source.count - span + 1
            var index = 0
            while index < source.count - span * 2 + 1 {
                let left = values[offset + index]
                let right = values[offset + index + span]
                values.append(left > right ? left : right)
                index += 1
            }
            offset += width
            span *= 2
        }
        self.values = values
        count = source.count
    }

    func maximum(_ lower: Int, _ upper: Int) -> Float {
        let length = upper - lower + 1
        let level = Int.bitWidth - 1 - length.leadingZeroBitCount
        let offset = level * count - ((1 << level) - 1 - level)
        let left = values[offset + lower]
        let right = values[offset + upper - (1 << level) + 1]
        return left > right ? left : right
    }
}
