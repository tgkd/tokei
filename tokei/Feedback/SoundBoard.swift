import AVFoundation

@MainActor
final class SoundBoard {
    struct SoundTicket: Hashable {
        let voice: Int
        let serial: Int
    }

    private struct Request {
        let kind: FeedbackCue.Kind
        let timbre: SoundTimbre
        let volume: Float
        let time: TimeInterval
    }

    private struct WaitingPlay {
        let ticket: SoundTicket
        let volume: Float
        let requestedAt: TimeInterval
    }

    private struct ContextKey: Hashable {
        let timbre: SoundTimbre
        let kind: FeedbackCue.Kind
        let context: CueContext
    }

    private let output = SoundOutput()
    private var busyUntil = [TimeInterval](repeating: 0, count: SoundOutput.voiceCount)
    private var sounds: [SoundTimbre: [FeedbackCue.Kind: [AVAudioPCMBuffer]]] = [:]
    private var rendering: Set<SoundTimbre> = []
    private var waiting: Request?
    private var lastPlayed: [FeedbackCue.Kind: (variant: Int, time: TimeInterval)] = [:]
    private var wantsRunning = false
    private var pendingPause: Task<Void, Never>?
    private var contextual: [ContextKey: [[Float]]] = [:]
    private var serialCounter = 0
    private var voiceSerial = [Int](repeating: 0, count: SoundOutput.voiceCount)
    private var renderingSerials: Set<Int> = []
    private var cancelledSerials: Set<Int> = []
    private var renderingContexts: Set<ContextKey> = []
    private var waitingContexts: [ContextKey: WaitingPlay] = [:]

    private static let waitLimit: TimeInterval = 0.3
    private static let contextWaitLimit: TimeInterval = 1.0
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

    @discardableResult
    func play(_ kind: FeedbackCue.Kind, timbre: SoundTimbre, volume: Float = 1, context: CueContext = .none) -> SoundTicket? {
        guard wantsRunning, !timbre.silent.contains(kind) else { return nil }
        if context != .none, timbre.contextual != nil {
            return playContextual(kind: kind, timbre: timbre, volume: volume, context: context)
        }
        return playRegular(kind: kind, timbre: timbre, volume: volume)
    }

    @discardableResult
    func play(sequence: SoundSequence, timbre: SoundTimbre, volume: Float = 1) -> SoundTicket? {
        guard wantsRunning else { return nil }
        let slot = busyUntil.indices.min(by: { busyUntil[$0] < busyUntil[$1] }) ?? 0
        let ticket = SoundTicket(voice: slot, serial: nextSerial())
        renderingSerials.insert(ticket.serial)
        Task {
            let rate = output.format?.sampleRate
            let samples = await Task.detached(priority: .userInitiated) {
                rate.map { SoundSynth.mix(sequence, rate: $0) } ?? []
            }.value
            install(samples, ticket: ticket, volume: volume)
        }
        return ticket
    }

    func cancel(_ ticket: SoundTicket) {
        if voiceSerial[ticket.voice] == ticket.serial {
            output.stop(voice: ticket.voice)
            voiceSerial[ticket.voice] = 0
            busyUntil[ticket.voice] = ProcessInfo.processInfo.systemUptime
        } else if renderingSerials.contains(ticket.serial) {
            cancelledSerials.insert(ticket.serial)
        }
    }

    private func playRegular(kind: FeedbackCue.Kind, timbre: SoundTimbre, volume: Float) -> SoundTicket? {
        let now = ProcessInfo.processInfo.systemUptime
        guard let library = sounds[timbre] else {
            waiting = Request(kind: kind, timbre: timbre, volume: volume, time: now)
            prepare(timbre)
            return nil
        }
        guard !throttled(kind, now: now) else { return nil }
        guard let buffers = library[kind], !buffers.isEmpty else { return nil }
        let variant = pickVariant(in: buffers.count, kind: kind)
        return schedule(buffer: buffers[variant], kind: kind, variant: variant, volume: volume)
    }

    private func playContextual(kind: FeedbackCue.Kind, timbre: SoundTimbre, volume: Float, context: CueContext) -> SoundTicket? {
        let key = ContextKey(timbre: timbre, kind: kind, context: context)
        if let cached = contextual[key] {
            if cached.isEmpty {
                return playRegular(kind: kind, timbre: timbre, volume: volume)
            }
            return schedule(variants: cached, kind: kind, volume: volume)
        }
        guard Self.hasContextualDesign(key) else {
            contextual[key] = []
            return playRegular(kind: kind, timbre: timbre, volume: volume)
        }
        let slot = busyUntil.indices.min(by: { busyUntil[$0] < busyUntil[$1] }) ?? 0
        let ticket = SoundTicket(voice: slot, serial: nextSerial())
        renderingSerials.insert(ticket.serial)
        if let previous = waitingContexts[key] {
            renderingSerials.remove(previous.ticket.serial)
        }
        waitingContexts[key] = WaitingPlay(ticket: ticket, volume: volume, requestedAt: ProcessInfo.processInfo.systemUptime)
        if !renderingContexts.contains(key) {
            render(key, leadingFirst: true)
        }
        return ticket
    }

    func prewarm(_ kind: FeedbackCue.Kind, timbre: SoundTimbre, contexts: [CueContext]) {
        guard timbre.contextual != nil else { return }
        for context in contexts {
            let key = ContextKey(timbre: timbre, kind: kind, context: context)
            guard contextual[key] == nil, !renderingContexts.contains(key) else { continue }
            guard Self.hasContextualDesign(key) else {
                contextual[key] = []
                continue
            }
            render(key, leadingFirst: false)
        }
    }

    private static func hasContextualDesign(_ key: ContextKey) -> Bool {
        guard let index = FeedbackCue.Kind.allCases.firstIndex(of: key.kind) else { return false }
        var scratch = SoundSynth.Random(seed: key.timbre.seed(kind: index, variant: 0) ^ key.context.seed)
        return key.timbre.contextual?(key.kind, key.context, &scratch) != nil
    }

    private func render(_ key: ContextKey, leadingFirst: Bool) {
        guard let rate = output.format?.sampleRate else { return }
        renderingContexts.insert(key)
        let total = key.timbre.variants(of: key.kind)
        let leading = leadingFirst ? 0..<min(1, total) : 0..<total
        Task {
            let first = await Task.detached(priority: leadingFirst ? .userInitiated : .utility) {
                SoundSynth.contextualSamples(timbre: key.timbre, kind: key.kind, context: key.context, rate: rate, variants: leading)
            }.value
            installContext(first, key: key)
            if leading.upperBound < total {
                let rest = await Task.detached(priority: .utility) {
                    SoundSynth.contextualSamples(timbre: key.timbre, kind: key.kind, context: key.context, rate: rate, variants: leading.upperBound..<total)
                }.value
                contextual[key] = (contextual[key] ?? []) + rest
            }
            renderingContexts.remove(key)
        }
    }

    private func schedule(buffer: AVAudioPCMBuffer, kind: FeedbackCue.Kind, variant: Int, volume: Float) -> SoundTicket? {
        let now = ProcessInfo.processInfo.systemUptime
        guard let slot = busyUntil.indices.min(by: { busyUntil[$0] < busyUntil[$1] }) else { return nil }
        let serial = nextSerial()
        output.play(buffer, voice: slot, volume: volume)
        voiceSerial[slot] = serial
        busyUntil[slot] = now + Double(buffer.frameLength) / buffer.format.sampleRate
        lastPlayed[kind] = (variant, now)
        schedulePause()
        return SoundTicket(voice: slot, serial: serial)
    }

    private func schedule(variants: [[Float]], kind: FeedbackCue.Kind, volume: Float) -> SoundTicket? {
        let now = ProcessInfo.processInfo.systemUptime
        guard !throttled(kind, now: now) else { return nil }
        guard !variants.isEmpty, let format = output.format else { return nil }
        let variant = pickVariant(in: variants.count, kind: kind)
        guard let buffer = SoundSynth.buffer(variants[variant], format: format) else { return nil }
        return schedule(buffer: buffer, kind: kind, variant: variant, volume: volume)
    }

    private func schedule(_ samples: [Float], ticket: SoundTicket, volume: Float) {
        guard let format = output.format, let buffer = SoundSynth.buffer(samples, format: format) else { return }
        let now = ProcessInfo.processInfo.systemUptime
        output.play(buffer, voice: ticket.voice, volume: volume)
        voiceSerial[ticket.voice] = ticket.serial
        busyUntil[ticket.voice] = now + Double(buffer.frameLength) / buffer.format.sampleRate
        schedulePause()
    }

    private func install(_ samples: [Float], ticket: SoundTicket, volume: Float) {
        renderingSerials.remove(ticket.serial)
        let cancelled = cancelledSerials.remove(ticket.serial) != nil
        guard wantsRunning, !cancelled else { return }
        schedule(samples, ticket: ticket, volume: volume)
    }

    private func installContext(_ samples: [[Float]], key: ContextKey) {
        contextual[key] = samples
        guard let waiting = waitingContexts.removeValue(forKey: key) else { return }
        renderingSerials.remove(waiting.ticket.serial)
        let cancelled = cancelledSerials.remove(waiting.ticket.serial) != nil
        guard wantsRunning, !cancelled, !samples.isEmpty else { return }
        guard ProcessInfo.processInfo.systemUptime - waiting.requestedAt < Self.contextWaitLimit else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard !throttled(key.kind, now: now), let format = output.format else { return }
        let variant = pickVariant(in: samples.count, kind: key.kind)
        guard let buffer = SoundSynth.buffer(samples[variant], format: format) else { return }
        output.play(buffer, voice: waiting.ticket.voice, volume: waiting.volume)
        voiceSerial[waiting.ticket.voice] = waiting.ticket.serial
        busyUntil[waiting.ticket.voice] = now + Double(buffer.frameLength) / buffer.format.sampleRate
        lastPlayed[key.kind] = (variant, now)
        schedulePause()
    }

    private func nextSerial() -> Int {
        serialCounter += 1
        return serialCounter
    }

    private func pickVariant(in count: Int, kind: FeedbackCue.Kind) -> Int {
        var variant = Int.random(in: 0..<count)
        if count > 1, variant == lastPlayed[kind]?.variant {
            variant = (variant + Int.random(in: 1..<count)) % count
        }
        return variant
    }

    private func throttled(_ kind: FeedbackCue.Kind, now: TimeInterval) -> Bool {
        guard let last = lastPlayed[kind] else { return false }
        return now - last.time < Self.spacing[kind, default: 0]
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
