import Foundation

enum CoastDistance {
    static let limit: Float = 60

    private static let far = 1e20

    static func signedDegrees(coverage: [Float], threshold: Float, width: Int, height: Int) -> [Float] {
        let rowStep = 180 / Double(height)
        var toWater = [Float](repeating: 0, count: width * height)
        var toLand = [Float](repeating: 0, count: width * height)
        var result = [Float](repeating: 0, count: width * height)
        coverage.withUnsafeBufferPointer { coverage in
            toWater.withUnsafeMutableBufferPointer { toWater in
                squaredDegrees(coverage: coverage, threshold: threshold, towardLand: false, width: width, height: height, into: toWater)
            }
            toLand.withUnsafeMutableBufferPointer { toLand in
                squaredDegrees(coverage: coverage, threshold: threshold, towardLand: true, width: width, height: height, into: toLand)
            }
            toWater.withUnsafeBufferPointer { toWater in
                toLand.withUnsafeBufferPointer { toLand in
                    result.withUnsafeMutableBufferPointer { result in
                        let coverage = coverage.baseAddress!
                        let toWater = toWater.baseAddress!
                        let toLand = toLand.baseAddress!
                        let output = result.baseAddress!
                        DispatchQueue.concurrentPerform(iterations: height) { row in
                            let latitude = (0.5 - (Double(row) + 0.5) / Double(height)) * .pi
                            let columnStep = max(cos(latitude), 1e-4) * 360 / Double(width)
                            let above = (row > 0 ? row - 1 : 0) * width
                            let below = (row < height - 1 ? row + 1 : height - 1) * width
                            let base = row * width
                            var column = 0
                            while column < width {
                                let index = base + column
                                let value = coverage[index]
                                let exact = value > threshold
                                    ? Double(toWater[index]).squareRoot() - 0.5 * rowStep
                                    : 0.5 * rowStep - Double(toLand[index]).squareRoot()
                                let east = coverage[base + (column + 1) % width]
                                let west = coverage[base + (column + width - 1) % width]
                                let gradientX = Double(east - west) / (2 * columnStep)
                                let gradientY = Double(coverage[above + column] - coverage[below + column]) / (2 * rowStep)
                                let gradient = (gradientX * gradientX + gradientY * gradientY).squareRoot()
                                var distance = exact
                                if gradient > 1e-6 {
                                    let linear = clamp(Double(value - threshold) / gradient, 3 * rowStep)
                                    let blend = smoothstep(1, 2.5, exact.magnitude / rowStep)
                                    distance = linear + (exact - linear) * blend
                                }
                                output[index] = Float(clamp(distance, Double(limit)))
                                column += 1
                            }
                        }
                    }
                }
            }
        }
        return result
    }

    private static func squaredDegrees(
        coverage: UnsafeBufferPointer<Float>,
        threshold: Float,
        towardLand: Bool,
        width: Int,
        height: Int,
        into result: UnsafeMutableBufferPointer<Float>
    ) {
        let rowStep = 180 / Double(height)
        let span = max(width * 2, height)
        let chunks = 32
        var columns = [Float](repeating: 0, count: width * height)
        columns.withUnsafeMutableBufferPointer { columns in
            let columns = columns.baseAddress!
            let coverage = coverage.baseAddress!
            let result = result.baseAddress!
            DispatchQueue.concurrentPerform(iterations: chunks) { chunk in
                let scratch = Scratch(span: span)
                defer { scratch.release() }
                var column = chunk
                while column < width {
                    let input = scratch.input
                    let output = scratch.output
                    var row = 0
                    while row < height {
                        let isFeature = (coverage[row * width + column] > threshold) == towardLand
                        input[row] = isFeature ? 0 : far
                        row += 1
                    }
                    scratch.transform(count: height)
                    row = 0
                    while row < height {
                        let squared = output[row] * rowStep * rowStep
                        columns[row * width + column] = Float(squared < far ? squared : far)
                        row += 1
                    }
                    column += chunks
                }
            }
            let half = width / 2
            DispatchQueue.concurrentPerform(iterations: chunks) { chunk in
                let scratch = Scratch(span: span)
                defer { scratch.release() }
                var row = chunk
                while row < height {
                    let latitude = (0.5 - (Double(row) + 0.5) / Double(height)) * .pi
                    let columnStep = max(cos(latitude), 1e-4) * 360 / Double(width)
                    let scale = columnStep * columnStep
                    let base = row * width
                    let input = scratch.input
                    let output = scratch.output
                    var index = 0
                    while index < width * 2 {
                        input[index] = Double(columns[base + (index - half + width) % width]) / scale
                        index += 1
                    }
                    scratch.transform(count: width * 2)
                    var column = 0
                    while column < width {
                        let squared = output[column + half] * scale
                        result[base + column] = Float(squared < far ? squared : far)
                        column += 1
                    }
                    row += chunks
                }
            }
        }
    }

    private struct Scratch {
        let input: UnsafeMutablePointer<Double>
        let output: UnsafeMutablePointer<Double>
        let parabolas: UnsafeMutablePointer<Int>
        let bounds: UnsafeMutablePointer<Double>

        init(span: Int) {
            input = .allocate(capacity: span)
            output = .allocate(capacity: span)
            parabolas = .allocate(capacity: span)
            bounds = .allocate(capacity: span + 1)
        }

        func release() {
            input.deallocate()
            output.deallocate()
            parabolas.deallocate()
            bounds.deallocate()
        }

        func transform(count n: Int) {
            let f = input
            let v = parabolas
            let z = bounds
            let d = output
            var k = 0
            v[0] = 0
            z[0] = -.infinity
            z[1] = .infinity
            var q = 1
            while q < n {
                let fq = f[q] + Double(q * q)
                var s = (fq - (f[v[k]] + Double(v[k] * v[k]))) / Double(2 * (q - v[k]))
                while s <= z[k] {
                    k -= 1
                    s = (fq - (f[v[k]] + Double(v[k] * v[k]))) / Double(2 * (q - v[k]))
                }
                k += 1
                v[k] = q
                z[k] = s
                z[k + 1] = .infinity
                q += 1
            }
            k = 0
            q = 0
            while q < n {
                while z[k + 1] < Double(q) {
                    k += 1
                }
                let offset = Double(q - v[k])
                d[q] = offset * offset + f[v[k]]
                q += 1
            }
        }
    }

    private static func clamp(_ value: Double, _ bound: Double) -> Double {
        value < -bound ? -bound : (value > bound ? bound : value)
    }

    private static func smoothstep(_ edge0: Double, _ edge1: Double, _ x: Double) -> Double {
        let ratio = (x - edge0) / (edge1 - edge0)
        let t = ratio < 0 ? 0 : (ratio > 1 ? 1 : ratio)
        return t * t * (3 - 2 * t)
    }
}
