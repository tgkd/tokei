import Foundation
import simd

struct SnowTrail {
    struct Wave {
        let wavelength: Double
        let amplitude: Double
        let phase: Double

        func value(at distance: Double) -> Double {
            amplitude * sin(2 * .pi * distance / wavelength + phase)
        }
    }

    let radius: Double
    let widths: [Wave]
    let wiggles: [Wave]
    var last: SIMD3<Double>?
    var distance = 0.0

    static func random(radius: Double) -> SnowTrail {
        func wave(_ wavelengths: ClosedRange<Double>, _ amplitudes: ClosedRange<Double>) -> Wave {
            Wave(wavelength: radius * .random(in: wavelengths), amplitude: .random(in: amplitudes), phase: .random(in: 0..<(2 * .pi)))
        }
        return SnowTrail(
            radius: radius,
            widths: [wave(3.5...5, 0.1...0.16), wave(1.6...2.2, 0.05...0.08), wave(0.7...0.9, 0.025...0.04)],
            wiggles: [wave(5...7, 0.07...0.1), wave(2...2.6, 0.03...0.05)]
        )
    }

    var reach: Double {
        radius * (1 + widths.reduce(0) { $0 + $1.amplitude } + wiggles.reduce(0) { $0 + $1.amplitude })
    }

    func halfWidth(at distance: Double) -> Double {
        radius * (1 + widths.reduce(0) { $0 + $1.value(at: distance) })
    }

    func offset(at distance: Double) -> Double {
        radius * wiggles.reduce(0) { $0 + $1.value(at: distance) }
    }

    mutating func advance(to point: SIMD3<Double>) {
        if let last {
            distance += acos(min(max(dot(last, point), -1), 1))
        }
        last = point
    }
}
