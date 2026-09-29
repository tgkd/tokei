import Foundation
import simd

struct WeatherGrid: Sendable {
    let width: Int
    let height: Int
    let values: [Float]
    private let longitudeStep: Double
    private let latitudeStep: Double

    init?(_ field: GribField) {
        guard
            abs(field.firstLatitude - 90) < 1e-6,
            abs(field.firstLongitude) < 1e-6,
            abs(Double(field.width) * field.longitudeStep - 360) < 1e-6,
            abs(Double(field.height - 1) * field.latitudeStep - 180) < 1e-6,
            field.values.count == field.width * field.height
        else { return nil }
        width = field.width
        height = field.height
        values = field.values
        longitudeStep = field.longitudeStep
        latitudeStep = field.latitudeStep
    }

    func matches(_ other: WeatherGrid) -> Bool {
        width == other.width && height == other.height
    }

    func position(of direction: SIMD3<Double>) -> SIMD2<Double> {
        let latitude = asin(min(max(direction.y, -1), 1)) * 180 / .pi
        var longitude = atan2(direction.x, direction.z) * 180 / .pi
        if longitude < 0 {
            longitude += 360
        }
        return SIMD2(longitude / longitudeStep, (90 - latitude) / latitudeStep)
    }

    func value(column: Int, row: Int) -> Float {
        let wrapped = ((column % width) + width) % width
        let clamped = min(max(row, 0), height - 1)
        return values[clamped * width + wrapped]
    }

    func bilinear(at direction: SIMD3<Double>) -> Float {
        let position = position(of: direction)
        let column = Int(floor(position.x))
        let row = Int(floor(position.y))
        let tx = Float(position.x - floor(position.x))
        let ty = Float(position.y - floor(position.y))
        let top = value(column: column, row: row) * (1 - tx) + value(column: column + 1, row: row) * tx
        let bottom = value(column: column, row: row + 1) * (1 - tx) + value(column: column + 1, row: row + 1) * tx
        return top * (1 - ty) + bottom * ty
    }

    func nearest(at direction: SIMD3<Double>) -> Float {
        let position = position(of: direction)
        return value(column: Int(position.x.rounded()), row: Int(position.y.rounded()))
    }
}
