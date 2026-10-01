import AVFoundation

struct SoundTimbre: Hashable, Sendable {
    let id: String
    let shape: @Sendable (FeedbackCue.Kind, SoundSynth.Voice) -> SoundSynth.Voice
    let design: (@Sendable (FeedbackCue.Kind, inout SoundSynth.Random) -> SoundSynth.Design?)?
    let contextual: (@Sendable (FeedbackCue.Kind, CueContext, inout SoundSynth.Random) -> SoundSynth.Design?)?
    let train: SoundTrain?
    let silent: Set<FeedbackCue.Kind>
    private let counts: [FeedbackCue.Kind: Int]

    init(id: String, shape: @escaping @Sendable (FeedbackCue.Kind, SoundSynth.Voice) -> SoundSynth.Voice) {
        self.id = id
        self.shape = shape
        design = nil
        contextual = nil
        train = nil
        silent = []
        counts = [:]
    }

    init(id: String, variants: [FeedbackCue.Kind: Int], silent: Set<FeedbackCue.Kind> = [], design: @escaping @Sendable (FeedbackCue.Kind, inout SoundSynth.Random) -> SoundSynth.Design?, contextual: (@Sendable (FeedbackCue.Kind, CueContext, inout SoundSynth.Random) -> SoundSynth.Design?)? = nil, train: SoundTrain? = nil) {
        self.id = id
        shape = { _, voice in voice }
        self.design = design
        self.contextual = contextual
        self.train = train
        self.silent = silent
        counts = variants
    }

    func variants(of kind: FeedbackCue.Kind) -> Int {
        counts[kind] ?? SoundSynth.variants(of: kind)
    }

    static func == (lhs: SoundTimbre, rhs: SoundTimbre) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func seed(kind: Int, variant: Int) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in id.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01B3
        }
        return hash ^ (UInt64(kind) << 32) ^ UInt64(variant)
    }
}

struct SoundSequence: Sendable {
    struct HapticTick: Sendable {
        var intensity: Float
        var sharpness: Float
    }

    struct Entry: Sendable {
        var at: Double
        var gain = 1.0
        var design: (@Sendable (inout SoundSynth.Random) -> SoundSynth.Design)?
        var haptic: HapticTick?
    }

    var entries: [Entry]
    var seed: UInt64 = 0
}

struct SoundTrain: Sendable {
    var spacing: Double
    var limit: Int
    var haptics: Int
    var sharpness: Float
    var design: @Sendable (Double, inout SoundSynth.Random) -> SoundSynth.Design
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
        var spread = 1.0
        var jitter = 0.0
        var hiss = 0.0

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
            voice.startFrequency *= 1 + 0.05 * spread * amount
            voice.endFrequency *= 1 + 0.05 * spread * amount
            voice.decay *= 1 + 0.1 * spread * amount
            return voice
        }
    }

    struct Design {
        var layers: [any SoundLayer]
        var level: Double
        var floor = 150.0
    }

    static let variants = 8
    static let ceiling = 0.7
    private static let rapidVariants: [FeedbackCue.Kind: Int] = [.tick: 12, .carve: 16]

    static func variants(of kind: FeedbackCue.Kind) -> Int {
        rapidVariants[kind] ?? variants
    }

    static func samples(timbre: SoundTimbre, rate: Double) -> [FeedbackCue.Kind: [[Float]]] {
        var library: [FeedbackCue.Kind: [[Float]]] = [:]
        for (index, kind) in FeedbackCue.Kind.allCases.enumerated() where !timbre.silent.contains(kind) {
            library[kind] = (0..<timbre.variants(of: kind)).map { variant in
                var random = Random(seed: timbre.seed(kind: index, variant: variant))
                if let design = timbre.design?(kind, &random) {
                    return render(design, rate: rate, random: &random)
                }
                let voice = voice(for: kind, timbre: timbre).varied(by: random.signed())
                return waveform(voice, rate: rate, random: &random).map(Float.init)
            }
        }
        return library
    }

    static func contextualSamples(timbre: SoundTimbre, kind: FeedbackCue.Kind, context: CueContext, rate: Double, variants: Range<Int>? = nil) -> [[Float]] {
        guard let index = FeedbackCue.Kind.allCases.firstIndex(of: kind) else { return [] }
        return (variants ?? 0..<timbre.variants(of: kind)).compactMap { variant in
            var random = Random(seed: timbre.seed(kind: index, variant: variant) ^ context.seed)
            guard let design = timbre.contextual?(kind, context, &random) else { return nil }
            return render(design, rate: rate, random: &random)
        }
    }

    static func voice(for kind: FeedbackCue.Kind, timbre: SoundTimbre) -> Voice {
        timbre.shape(kind, voice(for: kind))
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
        case .carve:
            Voice(startFrequency: 640, endFrequency: 440, glide: 0.02, vibratoDepth: 0.1, vibratoRate: 65, vibratoDecay: 0.05, attack: 0.003, decay: 0.016, duration: 0.06, gain: 0.13, overtone: 0.4, noise: 0.15, spread: 3, jitter: 0.008, hiss: 1)
        }
    }

    static func waveform(_ voice: Voice, rate: Double, random: inout Random) -> [Double] {
        let delay = voice.jitter > 0 ? Int(voice.jitter * random.unit() * rate) : 0
        let count = Int(voice.duration * rate)
        var samples = [Double](repeating: 0, count: delay + count)
        var phase = 0.0
        var rub = 0.0
        for index in 0..<count {
            let time = Double(index) / rate
            phase += 2 * .pi * voice.frequency(at: time) / rate
            let tone = sin(phase) + voice.overtone * sin(2 * phase) + voice.bell * sin(2.76 * phase)
            let noise = voice.noise * random.signed() * exp(-time / 0.004)
            if voice.hiss > 0 {
                rub += (random.signed() - rub) * 0.3
            }
            samples[delay + index] = (tone + noise + voice.hiss * rub) * voice.envelope(at: time) * voice.gain
        }
        return samples
    }

    static func render(_ design: Design, rate: Double, random: inout Random) -> [Float] {
        var mix = [Double](repeating: 0, count: max(Int((design.layers.map(\.end).max() ?? 0) * rate), 1))
        mix.withUnsafeMutableBufferPointer { buffer in
            for layer in design.layers {
                layer.add(into: buffer, rate: rate, random: &random)
            }
        }
        var floor = Biquad.highPass(frequency: design.floor, resonance: 0.707, rate: rate)
        for index in mix.indices {
            mix[index] = floor.process(mix[index])
        }
        let peak = mix.reduce(0) { max($0, abs($1)) }
        guard peak > 0 else { return [0] }
        let gain = min(pow(10, (design.level - loudness(mix, rate: rate)) / 20), 1.6 * ceiling / peak)
        let end = (mix.lastIndex { abs($0) > peak * 0.003 } ?? 0) + 1
        let fade = Double(min(Int(0.004 * rate), end))
        return (0..<end).map { index in
            Float(limited(mix[index] * gain) * min(Double(end - index) / fade, 1))
        }
    }

    static func limited(_ sample: Double) -> Double {
        let knee = 0.45
        let magnitude = abs(sample)
        guard magnitude > knee else { return sample }
        let room = ceiling - knee
        return (knee + room * tanh((magnitude - knee) / room)) * (sample < 0 ? -1 : 1)
    }

    static func mix(_ sequence: SoundSequence, rate: Double) -> [Float] {
        var mix = [Double]()
        for (index, entry) in sequence.entries.enumerated() {
            guard let design = entry.design else { continue }
            var random = Random(seed: sequence.seed ^ UInt64(index))
            let rendered = render(design(&random), rate: rate, random: &random)
            let offset = Int(entry.at * rate)
            let needed = offset + rendered.count
            if needed > mix.count {
                mix.append(contentsOf: repeatElement(0, count: needed - mix.count))
            }
            for (sampleIndex, sample) in rendered.enumerated() {
                mix[offset + sampleIndex] += Double(sample) * entry.gain
            }
        }
        guard !mix.isEmpty else { return [0] }
        let fade = max(Int(0.004 * rate), 1)
        return mix.indices.map { index in
            Float(limited(mix[index]) * min(Double(mix.count - index) / Double(fade), 1))
        }
    }

    static func loudness(_ samples: [Double], rate: Double) -> Double {
        var weighting = Biquad.highPass(frequency: 400, resonance: 0.707, rate: rate)
        let window = max(Int(0.05 * rate), 1)
        var squares = [Double](repeating: 0, count: samples.count)
        var energy = 0.0
        var loudest = 0.0
        for index in samples.indices {
            let weighted = weighting.process(samples[index])
            squares[index] = weighted * weighted
            energy += squares[index]
            if index >= window {
                energy -= squares[index - window]
            }
            loudest = max(loudest, energy)
        }
        return 10 * log10(max(loudest / Double(window), 1e-12))
    }

    static func buffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard
            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
            let channel = buffer.floatChannelData?[0]
        else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            guard let base = source.baseAddress else { return }
            channel.update(from: base, count: source.count)
        }
        return buffer
    }
}
