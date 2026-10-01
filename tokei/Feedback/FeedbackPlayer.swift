import CoreHaptics

struct FeedbackTicket {
    var sound: SoundBoard.SoundTicket?
    var haptics: (any CHHapticPatternPlayer)?
}

@MainActor
final class FeedbackPlayer {
    private let sounds = SoundBoard()
    private let wobble = WobbleHaptics()

    func setSoundActive(_ active: Bool, timbre: SoundTimbre?) {
        sounds.setActive(active, timbre: timbre)
    }

    @discardableResult
    func play(_ cue: FeedbackCue, style: SceneStyle, soundEnabled: Bool, volume: Float = 1) -> SoundBoard.SoundTicket? {
        if cue.kind == .release {
            wobble.play(following: style.effects.press.releaseSpring)
        }
        if cue.kind == .press, style.effects.press.followHaptic {
            wobble.play(following: style.effects.press.pressSpring)
        }
        guard let timbre = style.soundTimbre, soundEnabled else { return nil }
        return sounds.play(cue.kind, timbre: timbre, volume: volume, context: cue.context)
    }

    @discardableResult
    func play(_ sequence: SoundSequence, style: SceneStyle, soundEnabled: Bool) -> FeedbackTicket {
        var ticket = FeedbackTicket()
        var ticks: [SoundSequence.HapticTick] = []
        var delays: [Double] = []
        for entry in sequence.entries {
            if let tick = entry.haptic {
                ticks.append(tick)
                delays.append(entry.at)
            }
        }
        ticket.haptics = wobble.play(ticks, delays: delays)
        guard let timbre = style.soundTimbre, soundEnabled, sequence.entries.contains(where: { $0.design != nil }) else { return ticket }
        ticket.sound = sounds.play(sequence: sequence, timbre: timbre)
        return ticket
    }

    @discardableResult
    func train(_ train: SoundTrain, speed: Double, style: SceneStyle, soundEnabled: Bool) -> FeedbackTicket {
        let tau = CameraMotion.inertiaTime
        var entries: [SoundSequence.Entry] = []
        for k in 0..<train.limit {
            let argument = 1 - Double(k) * train.spacing / (tau * speed)
            guard argument > 0 else { break }
            let time = -tau * log(argument)
            let speedFraction = min(speed * exp(-time / tau) / 10, 1)
            let gain = 0.35 + 0.65 * speedFraction
            var entry = SoundSequence.Entry(at: time, gain: gain)
            entry.design = { random in train.design(speedFraction, &random) }
            if k < train.haptics {
                entry.haptic = SoundSequence.HapticTick(intensity: Float(0.3 + 0.5 * speedFraction), sharpness: train.sharpness)
            }
            entries.append(entry)
        }
        return play(SoundSequence(entries: entries), style: style, soundEnabled: soundEnabled)
    }

    func cancel(_ ticket: FeedbackTicket?) {
        guard let ticket else { return }
        if let sound = ticket.sound {
            sounds.cancel(sound)
        }
        if let haptics = ticket.haptics {
            try? haptics.cancel()
        }
    }

    func cancel(_ ticket: SoundBoard.SoundTicket?) {
        guard let ticket else { return }
        sounds.cancel(ticket)
    }

    func prewarm(_ kind: FeedbackCue.Kind, contexts: [CueContext], style: SceneStyle, soundEnabled: Bool) {
        guard soundEnabled, let timbre = style.soundTimbre else { return }
        sounds.prewarm(kind, timbre: timbre, contexts: contexts)
    }

    func grain(_ kind: FeedbackCue.Kind, style: SceneStyle, soundEnabled: Bool, strength: Double) {
        wobble.tick(intensity: Float(0.25 + 0.45 * strength), sharpness: Float(style.effects.drag.grainSharpness))
        guard let timbre = style.soundTimbre, soundEnabled else { return }
        sounds.play(kind, timbre: timbre, volume: Float(0.2 + 0.6 * strength))
    }
}
