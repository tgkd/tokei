import AVFoundation

@MainActor
final class SoundBoard {
    private struct Request {
        let kind: FeedbackCue.Kind
        let timbre: SoundTimbre
        let volume: Float
        let time: TimeInterval
    }

    private let output = SoundOutput()
    private var busyUntil = [TimeInterval](repeating: 0, count: SoundOutput.voiceCount)
    private var sounds: [SoundTimbre: [FeedbackCue.Kind: [AVAudioPCMBuffer]]] = [:]
    private var rendering: Set<SoundTimbre> = []
    private var waiting: Request?
    private var lastPlayed: [FeedbackCue.Kind: (variant: Int, time: TimeInterval)] = [:]
    private var wantsRunning = false
    private var pendingPause: Task<Void, Never>?

    private static let waitLimit: TimeInterval = 0.3
    private static let idleDelay: TimeInterval = 10
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
            output.start()
            schedulePause()
        } else {
            stop()
        }
    }

    func play(_ kind: FeedbackCue.Kind, timbre: SoundTimbre, volume: Float = 1) {
        guard wantsRunning else { return }
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
            let buffers = library[kind],
            !buffers.isEmpty,
            let slot = busyUntil.indices.min(by: { busyUntil[$0] < busyUntil[$1] })
        else { return }
        var variant = Int.random(in: 0..<buffers.count)
        if buffers.count > 1, variant == lastPlayed[kind]?.variant {
            variant = (variant + Int.random(in: 1..<buffers.count)) % buffers.count
        }
        let buffer = buffers[variant]
        output.play(buffer, voice: slot, volume: volume)
        busyUntil[slot] = now + Double(buffer.frameLength) / buffer.format.sampleRate
        lastPlayed[kind] = (variant, now)
        schedulePause()
    }

    private func schedulePause() {
        pendingPause?.cancel()
        let quiet = max(busyUntil.max() ?? 0, ProcessInfo.processInfo.systemUptime) + Self.idleDelay
        pendingPause = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(quiet - ProcessInfo.processInfo.systemUptime, 0)))
            guard !Task.isCancelled else { return }
            self?.output.pause()
        }
    }

    private func prepare(_ timbre: SoundTimbre) {
        guard sounds[timbre] == nil, !rendering.contains(timbre), let rate = output.format?.sampleRate else { return }
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
        guard let format = output.format else { return }
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
        pendingPause?.cancel()
        busyUntil = busyUntil.map { _ in 0 }
        output.stop()
    }
}
