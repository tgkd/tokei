import AVFoundation

@MainActor
final class SoundBoard {
    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    private var voices: [AVAudioPlayerNode] = []
    private var sounds: [SoundTimbre: [FeedbackCue.Kind: [AVAudioPCMBuffer]]] = [:]
    private var nextVoice = 0
    private var wantsRunning = false

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
    }

    func setActive(_ active: Bool) {
        wantsRunning = active
        if active {
            start()
        } else {
            stop()
        }
    }

    func play(_ kind: FeedbackCue.Kind, timbre: SoundTimbre) {
        guard wantsRunning else { return }
        if !engine.isRunning {
            start()
        }
        guard engine.isRunning, !voices.isEmpty, let buffer = sounds[timbre]?[kind]?.randomElement() else { return }
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !voice.isPlaying {
            voice.play()
        }
    }

    private func start() {
        guard let format, !engine.isRunning else { return }
        if sounds.isEmpty {
            for timbre in SoundTimbre.allCases {
                sounds[timbre] = SoundSynth.library(format: format, timbre: timbre)
            }
        }
        if voices.isEmpty {
            for _ in 0..<6 {
                let voice = AVAudioPlayerNode()
                engine.attach(voice)
                engine.connect(voice, to: engine.mainMixerNode, format: format)
                voices.append(voice)
            }
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient)
            try session.setActive(true)
            try engine.start()
            voices.forEach { $0.play() }
        } catch {
            engine.stop()
        }
    }

    private func stop() {
        guard engine.isRunning else { return }
        voices.forEach { $0.stop() }
        engine.stop()
    }
}
