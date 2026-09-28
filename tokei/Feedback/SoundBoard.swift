import AVFoundation

@MainActor
final class SoundBoard {
    private struct Request {
        let kind: FeedbackCue.Kind
        let timbre: SoundTimbre
        let volume: Float
        let time: TimeInterval
    }

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    private var voices: [AVAudioPlayerNode] = []
    private var busyUntil: [TimeInterval] = []
    private var sounds: [SoundTimbre: [FeedbackCue.Kind: [AVAudioPCMBuffer]]] = [:]
    private var rendering: Set<SoundTimbre> = []
    private var waiting: Request?
    private var lastPlayed: [FeedbackCue.Kind: (variant: Int, time: TimeInterval)] = [:]
    private var wantsRunning = false

    private static let voiceCount = 8
    private static let waitLimit: TimeInterval = 0.3
    private static let spacing: [FeedbackCue.Kind: TimeInterval] = [.tick: 0.03, .carve: 0.03]

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
    }

    func setActive(_ active: Bool, timbre: SoundTimbre?) {
        wantsRunning = active
        if active {
            if let timbre {
                prepare(timbre)
            }
            start()
        } else {
            stop()
        }
    }

    func play(_ kind: FeedbackCue.Kind, timbre: SoundTimbre, volume: Float = 1) {
        guard wantsRunning else { return }
        if !engine.isRunning {
            start()
        }
        let now = ProcessInfo.processInfo.systemUptime
        guard let library = sounds[timbre] else {
            waiting = Request(kind: kind, timbre: timbre, volume: volume, time: now)
            prepare(timbre)
            return
        }
        if let last = lastPlayed[kind], now - last.time < Self.spacing[kind, default: 0] {
            return
        }
        guard
            engine.isRunning,
            let buffers = library[kind],
            !buffers.isEmpty,
            let slot = voices.indices.min(by: { busyUntil[$0] < busyUntil[$1] })
        else { return }
        var variant = Int.random(in: 0..<buffers.count)
        if buffers.count > 1, variant == lastPlayed[kind]?.variant {
            variant = (variant + Int.random(in: 1..<buffers.count)) % buffers.count
        }
        let buffer = buffers[variant]
        let voice = voices[slot]
        voice.volume = volume
        voice.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !voice.isPlaying {
            voice.play()
        }
        busyUntil[slot] = now + Double(buffer.frameLength) / buffer.format.sampleRate
        lastPlayed[kind] = (variant, now)
    }

    private func start() {
        guard let format, !engine.isRunning else { return }
        if voices.isEmpty {
            for _ in 0..<Self.voiceCount {
                let voice = AVAudioPlayerNode()
                engine.attach(voice)
                engine.connect(voice, to: engine.mainMixerNode, format: format)
                voices.append(voice)
                busyUntil.append(0)
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

    private func prepare(_ timbre: SoundTimbre) {
        guard sounds[timbre] == nil, !rendering.contains(timbre), let rate = format?.sampleRate else { return }
        rendering.insert(timbre)
        Task {
            let samples = await Task.detached(priority: .userInitiated) {
                SoundSynth.samples(timbre: timbre, rate: rate)
            }.value
            install(samples, for: timbre)
        }
    }

    private func install(_ samples: [FeedbackCue.Kind: [[Float]]], for timbre: SoundTimbre) {
        rendering.remove(timbre)
        guard let format else { return }
        sounds[timbre] = samples.mapValues { variants in
            variants.compactMap { SoundSynth.buffer($0, format: format) }
        }
        guard let request = waiting, request.timbre == timbre else { return }
        waiting = nil
        if ProcessInfo.processInfo.systemUptime - request.time < Self.waitLimit {
            play(request.kind, timbre: timbre, volume: request.volume)
        }
    }

    private func stop() {
        guard engine.isRunning else { return }
        voices.forEach { $0.stop() }
        busyUntil = busyUntil.map { _ in 0 }
        engine.stop()
    }
}
