import AVFoundation

final class SoundOutput: @unchecked Sendable {
    static let voiceCount = 8

    let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    private let queue = DispatchQueue(label: "com.app.tokei.sound", qos: .userInteractive)
    private let engine = AVAudioEngine()
    private var voices: [AVAudioPlayerNode] = []

    func start() {
        queue.async {
            _ = self.resume()
        }
    }

    func play(_ buffer: AVAudioPCMBuffer, voice slot: Int, volume: Float) {
        queue.async {
            guard self.resume() else { return }
            let voice = self.voices[slot]
            voice.volume = volume
            voice.scheduleBuffer(buffer, at: nil, options: .interrupts)
            if !voice.isPlaying {
                voice.play()
            }
        }
    }

    func pause() {
        queue.async {
            guard self.engine.isRunning else { return }
            self.engine.pause()
        }
    }

    func stop(voice slot: Int) {
        queue.async {
            guard slot < self.voices.count else { return }
            self.voices[slot].stop()
        }
    }

    func stop() {
        queue.async {
            self.voices.forEach { $0.stop() }
            self.engine.stop()
        }
    }

    private func resume() -> Bool {
        guard !engine.isRunning else { return true }
        guard let format else { return false }
        if voices.isEmpty {
            for _ in 0..<Self.voiceCount {
                let voice = AVAudioPlayerNode()
                engine.attach(voice)
                engine.connect(voice, to: engine.mainMixerNode, format: format)
                voices.append(voice)
            }
        }
        do {
            let session = AVAudioSession.sharedInstance()
            if session.category != .ambient {
                try session.setCategory(.ambient)
            }
            try session.setActive(true)
            try engine.start()
            voices.forEach { $0.play() }
            return true
        } catch {
            engine.stop()
            return false
        }
    }
}
