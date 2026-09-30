import Foundation
import simd

struct PetalBurst: Equatable {
    let origin: SIMD3<Double>
    let spread: Double
    let down: SIMD3<Double>
    let wind: SIMD3<Double>
    let start: Date
    let count: Int
    let seed: UInt32

    func end(tuning: EffectTuning.Petals) -> Date {
        start.addingTimeInterval(tuning.stagger + tuning.lifetime)
    }
}

struct PetalFlight: Equatable {
    let burst: PetalBurst
    let age: Double

    func uniforms(tuning: EffectTuning.Petals) -> PetalUniforms {
        let origin = SIMD4<Float>(SIMD3<Float>(burst.origin), Float(burst.spread))
        let down = SIMD4<Float>(SIMD3<Float>(burst.down), Float(age))
        let wind = SIMD4<Float>(SIMD3<Float>(burst.wind), Float(burst.seed))
        let motion = SIMD4<Float>(Float(tuning.fall), Float(tuning.drag), Float(tuning.launch), Float(tuning.lifetime))
        let shape = SIMD4<Float>(Float(tuning.size), Float(tuning.flutter), Float(tuning.spin), Float(tuning.lift))
        let timing = SIMD4<Float>(Float(tuning.stagger), Float(burst.count), 0, 0)
        return PetalUniforms(origin: origin, down: down, wind: wind, motion: motion, shape: shape, timing: timing)
    }
}

struct PetalUniforms {
    var origin: SIMD4<Float>
    var down: SIMD4<Float>
    var wind: SIMD4<Float>
    var motion: SIMD4<Float>
    var shape: SIMD4<Float>
    var timing: SIMD4<Float>
}

extension SceneEffects {
    static let petalCapacity = 900
    static let burstCapacity = 32

    func admits(petals count: Int) -> Bool {
        petals.count < Self.burstCapacity && petals.reduce(0) { $0 + $1.count } + count <= Self.petalCapacity
    }

    func petalFlights(at date: Date, tuning: EffectTuning) -> [PetalFlight] {
        guard let petalTuning = tuning.petals else { return [] }
        return petals.compactMap { burst in
            let age = date.timeIntervalSince(burst.start)
            guard age >= 0, date < burst.end(tuning: petalTuning) else { return nil }
            return PetalFlight(burst: burst, age: age)
        }
    }

    func petalEnd(tuning: EffectTuning) -> Date? {
        guard let petalTuning = tuning.petals else { return petals.map(\.start).min() }
        return petals.map { $0.end(tuning: petalTuning) }.min()
    }
}
