import Foundation

extension SoundTimbre {
    static let mosaic = SoundTimbre(id: "mosaic", variants: [.press: 10, .pop: 8, .release: 8]) { kind, random in
        MosaicSound.design(for: kind, random: &random)
    }
}

enum MosaicSound {
    private typealias Grains = SoundSynth.Grains
    private typealias Wash = SoundSynth.Wash
    private typealias Ring = SoundSynth.Ring
    private typealias Partial = SoundSynth.Ring.Partial

    private static let plateRatios = [1.0, 1.455, 1.802, 2.584]
    private static let plateDecays = [0.02, 0.012, 0.009, 0.006]
    private static let plateGains = [1.0, 0.5, 0.35, 0.2]

    static let cascadeHaptics: SoundSequence = {
        let tuning = EffectTuning.mosaic.ripple
        let steps = 240
        let samples = (0..<steps).map { step -> (time: Double, density: Double) in
            let time = tuning.duration * (Double(step) + 0.5) / Double(steps)
            return (time, sin(min(tuning.speed * time, .pi)) * exp(-tuning.decay * time))
        }
        let total = samples.reduce(0) { $0 + $1.density }
        let peak = max(samples.map(\.density).max() ?? 1, 1e-6)
        var entries: [SoundSequence.Entry] = []
        var running = 0.0
        var next = 0
        for sample in samples {
            running += sample.density
            while next < 8, running >= (Double(next) + 0.5) / 8 * total {
                let intensity = Float(0.3 + 0.4 * sample.density / peak)
                entries.append(SoundSequence.Entry(at: sample.time, haptic: SoundSequence.HapticTick(intensity: intensity, sharpness: 0.75)))
                next += 1
            }
        }
        return SoundSequence(entries: entries)
    }()

    static func design(for kind: FeedbackCue.Kind, random: inout SoundSynth.Random) -> SoundSynth.Design? {
        switch kind {
        case .tick: tick(&random)
        case .dayTick: clonk(&random)
        case .press: clack(&random)
        case .release: settle(&random)
        case .pop: cascade(&random)
        case .snap: castanets(&random)
        case .inflate: assemble(&random)
        case .carve: flip(&random)
        }
    }

    private static func tile(at time: Double, pitch: Double, decayScale: Double, gain: Double, random: inout SoundSynth.Random) -> [any SoundLayer] {
        var partials: [Partial] = []
        for index in plateRatios.indices {
            partials.append(Partial(
                frequency: pitch * plateRatios[index],
                decay: plateDecays[index] * decayScale * random.between(0.85...1.15),
                gain: gain * plateGains[index]
            ))
        }
        return [
            Wash(at: time, attack: 0.0001, decay: 0.0003, frequency: 7000, resonance: 0.7, gain: gain * 0.3),
            Ring(at: time, partials: partials),
        ]
    }

    private static func cascade(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let tuning = EffectTuning.mosaic.ripple
        let peak = atan(tuning.speed / tuning.decay) / tuning.speed
        var layers = tile(at: 0, pitch: random.between(3000...3400), decayScale: 1, gain: 0.6, random: &random)
        layers.append(Grains(at: 0.03, rise: peak, fall: 1 / tuning.decay, density: random.between(220...300), band: 2000...5000, cycles: 3...6, resonance: 4, grit: 1.5, gain: 0.8))
        layers.append(Wash(attack: 0.003, decay: 0.03, frequency: 400, resonance: 0.9, gain: 0.25))
        return SoundSynth.Design(layers: layers, level: -20)
    }

    private static func clack(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers: [any SoundLayer] = []
        let count = Int.random(in: 2...3, using: &random)
        for _ in 0..<count {
            layers += tile(at: random.between(0...0.015), pitch: random.between(1800...3000), decayScale: 0.9, gain: random.between(0.5...0.8), random: &random)
        }
        layers.append(Wash(attack: 0.002, decay: 0.02, frequency: 220, resonance: 0.9, gain: 0.4))
        return SoundSynth.Design(layers: layers, level: -21, floor: 100)
    }

    private static func settle(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers: [any SoundLayer] = []
        let count = Int.random(in: 5...8, using: &random)
        var time = 0.0
        var gap = 0.03
        for index in 0..<count {
            layers += tile(at: time, pitch: random.between(2500...4200), decayScale: 0.7, gain: 0.6 * pow(0.82, Double(index)), random: &random)
            time += gap * random.between(0.8...1.2)
            gap *= 0.78
        }
        return SoundSynth.Design(layers: layers, level: -25)
    }

    private static func flip(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers = tile(at: random.between(0...0.004), pitch: random.between(2000...3500), decayScale: 0.8, gain: 0.7, random: &random)
        layers.append(Wash(attack: 0.001, decay: 0.004, frequency: 500, resonance: 0.8, gain: 0.25))
        return SoundSynth.Design(layers: layers, level: -26)
    }

    private static func tick(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(layers: tile(at: 0, pitch: random.between(3500...4500), decayScale: 0.5, gain: 0.6, random: &random), level: -31)
    }

    private static func clonk(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers = tile(at: 0, pitch: random.between(660...740), decayScale: 6, gain: 0.8, random: &random)
        layers.append(Wash(attack: 0.001, decay: 0.012, frequency: 300, resonance: 0.9, gain: 0.35))
        return SoundSynth.Design(layers: layers, level: -22, floor: 120)
    }

    private static func castanets(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers: [any SoundLayer] = []
        var time = 0.0
        for _ in 0..<Int.random(in: 2...3, using: &random) {
            layers.append(Ring(at: time, partials: [
                Partial(frequency: 2200 * random.between(0.97...1.03), decay: 0.008, gain: 0.6),
                Partial(frequency: 3400 * random.between(0.97...1.03), decay: 0.008, gain: 0.35),
            ]))
            layers.append(Wash(at: time, attack: 0.0005, decay: 0.005, frequency: 1200, resonance: 0.9, gain: 0.4))
            time += random.between(0.02...0.03)
        }
        return SoundSynth.Design(layers: layers, level: -20)
    }

    private static func assemble(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers: [any SoundLayer] = [
            Grains(rise: 0.5, fall: 0.15, density: 400, band: 2000...5000, cycles: 3...6, resonance: 4, grit: 1.5, gain: 0.7),
        ]
        let pitches = [2100.0, 2650.0, 3150.0]
        let times = [0.55, 0.62, 0.7]
        for index in pitches.indices {
            layers += tile(at: times[index], pitch: pitches[index] * random.between(0.995...1.005), decayScale: 4, gain: 0.5, random: &random)
        }
        return SoundSynth.Design(layers: layers, level: -20)
    }
}
