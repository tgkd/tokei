import CoreHaptics
import SwiftUI

@MainActor
final class WobbleHaptics {
    private let engine: CHHapticEngine?

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics, let engine = try? CHHapticEngine() else {
            engine = nil
            return
        }
        engine.playsHapticsOnly = true
        engine.isAutoShutdownEnabled = true
        engine.resetHandler = { [weak engine] in
            try? engine?.start()
        }
        self.engine = engine
    }

    func play(following spring: Spring) {
        guard let engine else { return }
        let duration = min(spring.settlingDuration, 0.8)
        let steps = 12
        let points = (0...steps).map { step in
            let time = duration * Double(step) / Double(steps)
            let displacement = abs(1 - spring.value(target: 1.0, time: time))
            return CHHapticParameterCurve.ControlPoint(relativeTime: time, value: Float(min(displacement, 1)))
        }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2),
            ],
            relativeTime: 0,
            duration: duration
        )
        let curve = CHHapticParameterCurve(parameterID: .hapticIntensityControl, controlPoints: points, relativeTime: 0)
        guard
            let pattern = try? CHHapticPattern(events: [event], parameterCurves: [curve]),
            let player = try? engine.makePlayer(with: pattern)
        else { return }
        try? engine.start()
        try? player.start(atTime: CHHapticTimeImmediate)
    }

    func tick(intensity: Float, sharpness: Float) {
        guard let engine else { return }
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
            ],
            relativeTime: 0
        )
        guard
            let pattern = try? CHHapticPattern(events: [event], parameters: []),
            let player = try? engine.makePlayer(with: pattern)
        else { return }
        try? engine.start()
        try? player.start(atTime: CHHapticTimeImmediate)
    }

    func play(_ ticks: [SoundSequence.HapticTick], delays: [Double]) -> (any CHHapticPatternPlayer)? {
        guard let engine, !ticks.isEmpty else { return nil }
        let events = zip(ticks, delays).map { tick, delay in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: tick.intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: tick.sharpness),
                ],
                relativeTime: delay
            )
        }
        guard
            let pattern = try? CHHapticPattern(events: events, parameters: []),
            let player = try? engine.makePlayer(with: pattern)
        else { return nil }
        try? engine.start()
        try? player.start(atTime: CHHapticTimeImmediate)
        return player
    }
}
