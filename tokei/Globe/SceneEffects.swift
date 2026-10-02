import Foundation
import SwiftUI
import simd

struct SceneEffects: Equatable {
    struct Follow: Equatable {
        let origin: SIMD3<Double>
        let velocity: SIMD3<Double>
        let target: SIMD3<Double>
        let start: Date

        func position(at date: Date, spring: Spring) -> SIMD3<Double> {
            guard date < start.addingTimeInterval(spring.settlingDuration) else { return target }
            let time = max(date.timeIntervalSince(start), 0)
            let gap = target - origin
            let travel = SIMD3(
                spring.value(target: gap.x, initialVelocity: velocity.x, time: time),
                spring.value(target: gap.y, initialVelocity: velocity.y, time: time),
                spring.value(target: gap.z, initialVelocity: velocity.z, time: time)
            )
            return normalize(origin + travel)
        }

        func velocity(at date: Date, spring: Spring) -> SIMD3<Double> {
            guard date < start.addingTimeInterval(spring.settlingDuration) else { return .zero }
            let time = max(date.timeIntervalSince(start), 0)
            let gap = target - origin
            return SIMD3(
                spring.velocity(target: gap.x, initialVelocity: velocity.x, time: time),
                spring.velocity(target: gap.y, initialVelocity: velocity.y, time: time),
                spring.velocity(target: gap.z, initialVelocity: velocity.z, time: time)
            )
        }
    }

    struct Press: Equatable {
        let point: SIMD3<Double>
        let start: Date
        var release: Date?
        var follow: Follow?
        var isAtRest = false

        func center(at date: Date, spring: Spring) -> SIMD3<Double> {
            follow?.position(at: date, spring: spring) ?? point
        }

        func restDate(tuning: EffectTuning) -> Date? {
            guard release == nil, !isAtRest else { return nil }
            let pressed = start.addingTimeInterval(tuning.press.pressSpring.settlingDuration)
            guard let follow else { return pressed }
            return max(pressed, follow.start.addingTimeInterval(tuning.drag.follow.settlingDuration))
        }

        mutating func pull(to target: SIMD3<Double>, at date: Date, spring: Spring) {
            let current = follow ?? Follow(origin: point, velocity: .zero, target: point, start: date)
            follow = Follow(
                origin: current.position(at: date, spring: spring),
                velocity: current.velocity(at: date, spring: spring),
                target: target,
                start: date
            )
            isAtRest = false
        }
    }

    struct Pop: Equatable {
        let point: SIMD3<Double>
        let start: Date
    }

    struct Fling: Equatable {
        let axis: SIMD3<Double>
        let stretch: Double
        let start: Date
    }

    struct Snow: Equatable {
        let epoch: Date
        let until: Date
    }

    struct Stir: Equatable {
        let epoch: Date
        let until: Date
    }

    var press: Press?
    var pop: Pop?
    var fling: Fling?
    var inflateStart: Date?
    var snow: Snow?
    var stir: Stir?
    var petals: [PetalBurst] = []

    enum Cadence {
        case moving
        case refilling
        case still
    }

    var isEmpty: Bool {
        press == nil && pop == nil && fling == nil && inflateStart == nil && snow == nil && stir == nil && petals.isEmpty
    }

    var cadence: Cadence {
        let pressMoves = press.map { $0.release != nil || !$0.isAtRest } ?? false
        if pressMoves || pop != nil || fling != nil || inflateStart != nil || stir != nil || !petals.isEmpty {
            return .moving
        }
        return snow == nil ? .still : .refilling
    }

    func snapshot(at date: Date, tuning: EffectTuning) -> EffectSnapshot {
        guard !isEmpty else { return .none }
        var snapshot = EffectSnapshot()
        var shape = matrix_identity_double3x3
        if let press {
            let amount = Self.pressAmount(press, at: date, tuning: tuning.press)
            let center = press.center(at: date, spring: tuning.drag.follow)
            snapshot.dentPoint = center
            snapshot.dentDepth = tuning.press.dentDepth * amount
            snapshot.dentRadius = tuning.press.dentRadius
            snapshot.dentShade = tuning.press.dentShade
            snapshot.frost = tuning.press.frost * max(amount, 0)
            snapshot.cracks = tuning.press.cracks * max(amount, 0)
            shape = shape * Self.stretch(along: center, by: -tuning.press.squash * amount)
        }
        if let pop {
            let age = max(date.timeIntervalSince(pop.start), 0)
            let amount = Self.impulse(tuning.pop.spring, at: age)
            snapshot.bumpPoint = pop.point
            snapshot.bumpHeight = tuning.pop.height * amount
            snapshot.bumpRadius = tuning.pop.radius
            snapshot.glow = tuning.pop.glow * max(amount, 0)
            if age < tuning.ripple.duration {
                snapshot.rippleOrigin = pop.point
                snapshot.rippleAge = age
                snapshot.rippleTilt = tuning.ripple.tilt
                snapshot.rippleLandShare = tuning.ripple.landShare
                snapshot.rippleFlash = tuning.ripple.flash
                snapshot.rippleDisplacement = tuning.ripple.displacement
                snapshot.rippleWavelength = tuning.ripple.wavelength
                snapshot.rippleSpeed = tuning.ripple.speed
                snapshot.rippleDecay = tuning.ripple.decay
            }
        }
        if let fling {
            let amount = fling.stretch * Self.impulse(tuning.fling.spring, at: max(date.timeIntervalSince(fling.start), 0))
            shape = shape * Self.stretch(along: fling.axis, by: amount)
        }
        if let inflateStart, let spring = tuning.inflate {
            snapshot.inflate = spring.value(target: 1.0, time: max(date.timeIntervalSince(inflateStart), 0))
        }
        if let snow {
            snapshot.snowClock = max(date.timeIntervalSince(snow.epoch), 0.001)
        }
        if let stir {
            snapshot.stirClock = max(date.timeIntervalSince(stir.epoch), 0)
        }
        snapshot.shape = shape
        return snapshot
    }

    func nextEnd(tuning: EffectTuning) -> Date? {
        ends(tuning: tuning).compactMap { $0 }.min()
    }

    func settled(at date: Date, tuning: EffectTuning) -> SceneEffects {
        var settled = self
        if let release = press?.release, release.addingTimeInterval(tuning.press.releaseSpring.settlingDuration) <= date {
            settled.press = nil
        }
        if let rest = press?.restDate(tuning: tuning), rest <= date {
            settled.press?.isAtRest = true
        }
        if let end = popEnd(tuning: tuning), end <= date {
            settled.pop = nil
        }
        if let fling, fling.start.addingTimeInterval(tuning.fling.spring.settlingDuration) <= date {
            settled.fling = nil
        }
        if let inflateStart, inflateStart.addingTimeInterval(tuning.inflate?.settlingDuration ?? 0) <= date {
            settled.inflateStart = nil
        }
        if let snow, snow.until <= date {
            settled.snow = nil
        }
        if let stir, stir.until <= date {
            settled.stir = nil
        }
        if let petalTuning = tuning.petals {
            settled.petals.removeAll { $0.end(tuning: petalTuning) <= date }
        } else {
            settled.petals.removeAll()
        }
        return settled
    }

    private func ends(tuning: EffectTuning) -> [Date?] {
        [
            press?.release.map { $0.addingTimeInterval(tuning.press.releaseSpring.settlingDuration) },
            press?.restDate(tuning: tuning),
            popEnd(tuning: tuning),
            fling.map { $0.start.addingTimeInterval(tuning.fling.spring.settlingDuration) },
            inflateStart.map { $0.addingTimeInterval(tuning.inflate?.settlingDuration ?? 0) },
            snow?.until,
            stir?.until,
            petalEnd(tuning: tuning),
        ]
    }

    private func popEnd(tuning: EffectTuning) -> Date? {
        pop.map { $0.start.addingTimeInterval(max(tuning.pop.spring.settlingDuration, tuning.ripple.duration)) }
    }

    private static func pressAmount(_ press: Press, at date: Date, tuning: EffectTuning.Press) -> Double {
        let held = max(date.timeIntervalSince(press.start), 0)
        let settled = press.start.addingTimeInterval(tuning.pressSpring.settlingDuration)
        guard let release = press.release else {
            return date < settled ? tuning.pressSpring.value(target: 1.0, time: held) : 1
        }
        let heldAtRelease = max(release.timeIntervalSince(press.start), 0)
        let amount = release < settled ? tuning.pressSpring.value(target: 1.0, time: heldAtRelease) : 1
        let velocity = release < settled ? tuning.pressSpring.velocity(target: 1.0, time: heldAtRelease) : 0
        let since = max(date.timeIntervalSince(release), 0)
        return amount + tuning.releaseSpring.value(target: -amount, initialVelocity: velocity, time: since)
    }

    private static func impulse(_ spring: Spring, at time: Double) -> Double {
        spring.value(target: 0.0, initialVelocity: 1.0, time: time) / impulsePeak(spring)
    }

    private static func impulsePeak(_ spring: Spring) -> Double {
        let omega = sqrt(spring.stiffness / spring.mass)
        let zeta = spring.damping / (2 * sqrt(spring.stiffness * spring.mass))
        guard zeta < 1 else {
            return max(spring.value(target: 0.0, initialVelocity: 1.0, time: 1 / omega), 1e-6)
        }
        let damped = omega * sqrt(1 - zeta * zeta)
        let peakTime = atan2(damped, zeta * omega) / damped
        return exp(-zeta * omega * peakTime) * sin(damped * peakTime) / damped
    }

    private static func stretch(along axis: SIMD3<Double>, by amount: Double) -> simd_double3x3 {
        let direction = normalize(axis)
        let along = max(1 + amount, 0.2)
        let across = 1 / sqrt(along)
        let projector = simd_double3x3(columns: (direction * direction.x, direction * direction.y, direction * direction.z))
        return projector * along + (matrix_identity_double3x3 - projector) * across
    }
}
