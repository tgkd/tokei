@MainActor
final class FeedbackPlayer {
    private let sounds = SoundBoard()
    private let wobble = WobbleHaptics()

    func setSoundActive(_ active: Bool) {
        sounds.setActive(active)
    }

    func play(_ cue: FeedbackCue, style: SceneStyle, soundEnabled: Bool) {
        if cue.kind == .release {
            wobble.play(following: style.effects.press.releaseSpring)
        }
        guard let timbre = style.soundTimbre, soundEnabled else { return }
        sounds.play(cue.kind, timbre: timbre)
    }
}
