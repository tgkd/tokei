import AVFoundation

enum SoundTimbre: CaseIterable {
    case soft
    case glass
}

enum SoundSynth {
    struct Voice {
        var startFrequency: Double
        var endFrequency: Double
        var glide: Double
        var vibratoDepth = 0.0
        var vibratoRate = 0.0
        var vibratoDecay = 1.0
        var attack: Double
        var decay: Double
        var duration: Double
        var gain: Double
        var overtone: Double
        var noise = 0.0
        var bell = 0.0

        func frequency(at time: Double) -> Double {
            let base = endFrequency + (startFrequency - endFrequency) * exp(-time / glide)
            let vibrato = vibratoDepth * exp(-time / vibratoDecay) * sin(2 * .pi * vibratoRate * time)
            return base * (1 + vibrato)
        }

        func envelope(at time: Double) -> Double {
            let rise = min(time / attack, 1)
            let fall = exp(-max(time - attack, 0) / decay)
            let tail = min((duration - time) / 0.005, 1)
            return rise * fall * max(tail, 0)
        }

        func varied(by amount: Double) -> Voice {
            var voice = self
            voice.startFrequency *= 1 + 0.05 * amount
            voice.endFrequency *= 1 + 0.05 * amount
            voice.decay *= 1 + 0.1 * amount
            return voice
        }
    }

    static let variants = 8

    static func library(format: AVAudioFormat, timbre: SoundTimbre) -> [FeedbackCue.Kind: [AVAudioPCMBuffer]] {
        var library: [FeedbackCue.Kind: [AVAudioPCMBuffer]] = [:]
        for kind in FeedbackCue.Kind.allCases {
            library[kind] = (0..<variants).compactMap { _ in
                render(voice(for: kind, timbre: timbre).varied(by: Double.random(in: -1...1)), format: format)
            }
        }
        return library
    }

    static func voice(for kind: FeedbackCue.Kind, timbre: SoundTimbre) -> Voice {
        var voice = voice(for: kind)
        if timbre == .glass {
            voice.startFrequency *= 2.2
            voice.endFrequency *= 2.2
            voice.decay *= 1.6
            voice.duration = min(voice.duration * 1.6, 0.6)
            voice.overtone = 0.2
            voice.bell = 0.45
            voice.gain *= 0.8
            voice.noise *= 0.5
        }
        return voice
    }

    static func voice(for kind: FeedbackCue.Kind) -> Voice {
        switch kind {
        case .tick:
            Voice(startFrequency: 2100, endFrequency: 2100, glide: 1, attack: 0.001, decay: 0.006, duration: 0.035, gain: 0.18, overtone: 0.3, noise: 0.15)
        case .dayTick:
            Voice(startFrequency: 900, endFrequency: 700, glide: 0.03, attack: 0.001, decay: 0.025, duration: 0.09, gain: 0.25, overtone: 0.5, noise: 0.2)
        case .press:
            Voice(startFrequency: 210, endFrequency: 150, glide: 0.04, attack: 0.004, decay: 0.035, duration: 0.12, gain: 0.35, overtone: 0.2, noise: 0.05)
        case .release:
            Voice(startFrequency: 330, endFrequency: 330, glide: 1, vibratoDepth: 0.12, vibratoRate: 16, vibratoDecay: 0.12, attack: 0.003, decay: 0.09, duration: 0.32, gain: 0.28, overtone: 0.25)
        case .pop:
            Voice(startFrequency: 480, endFrequency: 980, glide: 0.02, attack: 0.002, decay: 0.03, duration: 0.09, gain: 0.3, overtone: 0.1)
        case .snap:
            Voice(startFrequency: 1500, endFrequency: 1400, glide: 0.02, attack: 0.0005, decay: 0.01, duration: 0.05, gain: 0.22, overtone: 0.6, noise: 0.3)
        case .inflate:
            Voice(startFrequency: 90, endFrequency: 260, glide: 0.12, attack: 0.03, decay: 0.16, duration: 0.45, gain: 0.35, overtone: 0.3)
        }
    }

    static func render(_ voice: Voice, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let frames = AVAudioFrameCount(voice.duration * rate)
        guard
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
            let samples = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = frames
        var phase = 0.0
        for index in 0..<Int(frames) {
            let time = Double(index) / rate
            phase += 2 * .pi * voice.frequency(at: time) / rate
            let tone = sin(phase) + voice.overtone * sin(2 * phase) + voice.bell * sin(2.76 * phase)
            let noise = voice.noise * Double.random(in: -1...1) * exp(-time / 0.004)
            samples[index] = Float((tone + noise) * voice.envelope(at: time) * voice.gain)
        }
        return buffer
    }
}
