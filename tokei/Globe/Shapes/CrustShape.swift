import Foundation
import simd

enum CrustShape {
    static let domeHeight: Float = 0.008
    static let domeWidth: Float = 0.35
    static let seed: Float = 7

    static func lift(_ field: TerrainField) -> TerrainLift {
        var lift = SteppedShape.lift(field)
        let inland = SteppedShape.inland(field)
        let plates = CrustPlates(rows: MagmaLook.standard.plateScale, seed: seed, width: domeWidth)
        var row = 0
        while row < field.height {
            let latitude = (0.5 - (Float(row) + 0.5) / Float(field.height)) * CrustPlates.pi
            let cosine = max(cos(latitude), 1e-4)
            var index = row * field.width
            var column = 0
            while column < field.width {
                if inland[index] > 0 {
                    let longitude = ((Float(column) + 0.5) / Float(field.width) - 0.5) * 2 * CrustPlates.pi
                    lift.heights[index] += domeHeight * inland[index] * plates.dome(latitude: latitude, longitude: longitude, cosine: cosine)
                }
                index += 1
                column += 1
            }
            row += 1
        }
        return lift
    }
}

private struct CrustPlates {
    struct Point {
        let latitude: Float
        let longitude: Float
        let sinP: Float
        let cosP: Float
        let polar: Bool
    }

    struct Site {
        let latitude: Float
        let longitude: Float
        let sinF: Float
        let cosF: Float
        let jitter: SIMD2<Float>
    }

    struct Neighbour {
        let site: Int
        let across: Float
        let up: Float
        let polarBetween: Float
    }

    static let pi = Float(Double.pi)

    let rows: Float
    let seed: Float
    let band: Float
    let rise: Float
    private let waves: Float
    private let sinBand: Float
    private let cosBand: Float
    private let middles: [SIMD2<Float>]
    private let rowStarts: [Int]
    private let sites: [Site]
    private let neighbourStarts: [Int]
    private let neighbours: [Neighbour]

    init(rows: Float, seed: Float, width: Float) {
        let band = Self.pi / rows
        var middles: [SIMD2<Float>] = []
        var rowStarts: [Int] = []
        var sites: [Site] = []
        var places: [SIMD2<Float>] = []
        var row: Float = 0
        while row < rows {
            let middle = Self.pi * 0.5 - (row + 0.5) * band
            let sinMiddle = sin(middle)
            let cosMiddle = cos(middle)
            let columns = max((2 * rows * cosMiddle + 0.5).rounded(.down), 1)
            let spacing = 2 * Self.pi / columns
            middles.append(SIMD2(sinMiddle, cosMiddle))
            rowStarts.append(sites.count)
            var column: Float = 0
            while column < columns {
                let jitter = Self.hash(SIMD3(row, column, seed))
                let delta = (0.35 - 0.7 * jitter.y) * band
                let half2 = 0.5 * delta * delta
                sites.append(Site(
                    latitude: middle + delta,
                    longitude: (column + 0.15 + 0.7 * jitter.x) * spacing - Self.pi,
                    sinF: sinMiddle * (1 - half2) + cosMiddle * delta,
                    cosF: cosMiddle * (1 - half2) - sinMiddle * delta,
                    jitter: SIMD2(jitter.x, jitter.y)
                ))
                places.append(Self.site(row, column, rows: rows, seed: seed, band: band))
                column += 1
            }
            row += 1
        }
        rowStarts.append(sites.count)
        let rise = width * band
        let reach = 2.5 * (rise + band)
        let span = Int((reach / band).rounded(.up)) + 1
        let threshold = cos(reach)
        let units: [SIMD3<Float>] = places.map { SIMD3(cos($0.x) * sin($0.y), sin($0.x), cos($0.x) * cos($0.y)) }
        let rowCount = rowStarts.count - 1
        var neighbourStarts: [Int] = []
        var neighbours: [Neighbour] = []
        var siteRow = 0
        while siteRow < rowCount {
            let first = rowStarts[max(siteRow - span, 0)]
            let last = rowStarts[min(siteRow + span + 1, rowCount)]
            var index = rowStarts[siteRow]
            while index < rowStarts[siteRow + 1] {
                neighbourStarts.append(neighbours.count)
                let place = places[index]
                let unit = units[index]
                var other = first
                while other < last {
                    if other != index && dot(unit, units[other]) > threshold {
                        let partner = places[other]
                        let across = Self.wrap(partner.y - place.y)
                        neighbours.append(Neighbour(
                            site: other,
                            across: across,
                            up: partner.x - place.x,
                            polarBetween: 2 - 2 * (sin(place.x) * sin(partner.x) + cos(place.x) * cos(partner.x) * Self.cosine(across))
                        ))
                    }
                    other += 1
                }
                index += 1
            }
            siteRow += 1
        }
        neighbourStarts.append(neighbours.count)
        self.rows = rows
        self.seed = seed
        self.band = band
        self.rise = rise
        waves = max((rows * 0.2).rounded(.down), 2)
        sinBand = sin(band)
        cosBand = cos(band)
        self.middles = middles
        self.rowStarts = rowStarts
        self.sites = sites
        self.neighbourStarts = neighbourStarts
        self.neighbours = neighbours
    }

    func dome(latitude: Float, longitude: Float, cosine: Float) -> Float {
        let found = nearest(latitude: latitude, longitude: longitude, cosine: cosine)
        let point = found.point
        let own = chord(sites[found.site], point)
        let limit = 2 * (rise + max(own, 0).squareRoot())
        let farthest = limit * limit
        var dome: Float = 1
        var entry = neighbourStarts[found.site]
        let end = neighbourStarts[found.site + 1]
        while entry < end {
            let neighbour = neighbours[entry]
            let across = neighbour.across * point.cosP
            let between = point.polar ? neighbour.polarBetween : across * across + neighbour.up * neighbour.up
            if between < farthest {
                let distance = (chord(sites[neighbour.site], point) - own) / (2 * max(between, 1e-10).squareRoot())
                dome *= ToyTerrain.smoothstep(0, rise, distance)
            }
            entry += 1
        }
        return dome
    }

    private func nearest(latitude pointLatitude: Float, longitude pointLongitude: Float, cosine pointCosine: Float) -> (site: Int, point: Point) {
        let calm = ToyTerrain.smoothstep(0.08, 0.3, pointCosine) * 0.3 * band
        let latitude = pointLatitude + calm * sin(waves * pointLongitude + 1.7 * waves * pointLatitude + seed)
        let longitude = pointLongitude + calm / max(pointCosine, 0.2) * sin(1.3 * waves * pointLatitude - waves * pointLongitude + seed * 1.3)
        let sinP = sin(latitude)
        let cosP = cos(latitude)
        let row = min(max(((0.5 - latitude / Self.pi) * rows).rounded(.down), 0), rows - 1)
        let middle = Self.pi * 0.5 - (row + 0.5) * band
        let sinMiddle = middles[Int(row)].x
        let cosMiddle = middles[Int(row)].y
        let polar = cosP < 0.3
        var first: Float = 1e9
        var nearest = 0
        for dr in -1...1 {
            let r = row + Float(dr)
            if r < 0 || r >= rows {
                continue
            }
            let side = -Float(dr)
            let along: Float = dr == 0 ? 1 : cosBand
            let sinR = sinMiddle * along + cosMiddle * sinBand * side
            let cosR = cosMiddle * along - sinMiddle * sinBand * side
            let columns = max((2 * rows * cosR + 0.5).rounded(.down), 1)
            let spacing = 2 * Self.pi / columns
            let column = ((longitude + Self.pi) / spacing).rounded(.down)
            for dc in -1...1 {
                if Float(dc + 1) >= columns {
                    continue
                }
                let c = column + Float(dc)
                let wrapped = c < 0 ? c + columns : (c >= columns ? c - columns : c)
                let index = rowStarts[Int(r)] + Int(wrapped)
                let jitter = sites[index].jitter
                let delta = (0.35 - 0.7 * jitter.y) * band
                let offset = Self.wrap((c + 0.15 + 0.7 * jitter.x) * spacing - Self.pi - longitude)
                let chord: Float
                if polar {
                    let half2 = 0.5 * delta * delta
                    let sinF = sinR * (1 - half2) + cosR * delta
                    let cosF = cosR * (1 - half2) - sinR * delta
                    chord = 2 - 2 * (sinP * sinF + cosP * cosF * Self.cosine(offset))
                } else {
                    let across = offset * cosP
                    let up = middle + band * side + delta - latitude
                    chord = across * across + up * up
                }
                if chord < first {
                    first = chord
                    nearest = index
                }
            }
        }
        return (nearest, Point(latitude: latitude, longitude: longitude, sinP: sinP, cosP: cosP, polar: polar))
    }

    private func chord(_ site: Site, _ point: Point) -> Float {
        let offset = Self.wrap(site.longitude - point.longitude)
        if point.polar {
            return 2 - 2 * (point.sinP * site.sinF + point.cosP * site.cosF * Self.cosine(offset))
        }
        let across = offset * point.cosP
        let up = site.latitude - point.latitude
        return across * across + up * up
    }

    private static func site(_ row: Float, _ column: Float, rows: Float, seed: Float, band: Float) -> SIMD2<Float> {
        let latitude = pi * 0.5 - (row + 0.5) * band
        let columns = max((2 * rows * cos(latitude) + 0.5).rounded(.down), 1)
        let jitter = hash(SIMD3(row, column, seed))
        let delta = (0.35 - 0.7 * jitter.y) * band
        return SIMD2(latitude + delta, 2 * pi * (column + 0.15 + 0.7 * jitter.x) / columns - pi)
    }

    private static func wrap(_ angle: Float) -> Float {
        angle - 2 * pi * (angle / (2 * pi) + 0.5).rounded(.down)
    }

    private static func cosine(_ angle: Float) -> Float {
        if abs(angle) < 0.6 {
            let square = angle * angle
            return 1 - square * (0.5 - square * (1 / 24 - square / 720))
        }
        return cos(angle)
    }

    private static func hash(_ point: SIMD3<Float>) -> SIMD3<Float> {
        let scale = SIMD3<Float>(0.1031, 0.1030, 0.0973)
        var p = (-(point * scale).rounded(.down)).addingProduct(point, scale)
        let q = SIMD3(p.y, p.x, p.z) + 33.33
        p += (p.x * q.x).addingProduct(p.y, q.y).addingProduct(p.z, q.z)
        let sum = SIMD3(p.x, p.x, p.y) + SIMD3(p.y, p.x, p.x)
        let turned = SIMD3(p.z, p.y, p.x)
        return (-(sum * turned).rounded(.down)).addingProduct(sum, turned)
    }
}
