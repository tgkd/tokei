@MainActor
final class FeedbackPlayer {
    private let sounds = SoundBoard()
    private let wobble = WobbleHaptics()

    func setSoundActive(_ active: Bool, timbre: SoundTimbre?) {
        sounds.setActive(active, timbre: timbre)
    }

    func play(_ cue: FeedbackCue, style: SceneStyle, soundEnabled: Bool, volume: Float = 1) {
        if cue.kind == .release {
            wobble.play(following: style.effects.press.releaseSpring)
        }
        guard let timbre = style.soundTimbre, soundEnabled else { return }
        sounds.play(cue.kind, timbre: timbre, volume: volume)
    }

    func grain(_ kind: FeedbackCue.Kind, style: SceneStyle, soundEnabled: Bool, strength: Double) {
        wobble.tick(intensity: Float(0.25 + 0.45 * strength), sharpness: Float(style.effects.drag.grainSharpness))
        guard let timbre = style.soundTimbre, soundEnabled else { return }
        sounds.play(kind, timbre: timbre, volume: Float(0.2 + 0.6 * strength))
    }
}
