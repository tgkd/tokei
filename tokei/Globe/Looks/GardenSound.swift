import Foundation

extension SoundTimbre {
    static let garden = SoundTimbre(
        id: "garden",
        variants: [.press: 10, .pop: 8, .release: 8],
        design: { GardenSound.design(for: $0, random: &$1) },
        contextual: { GardenSound.contextual($0, $1, random: &$2) }
    )
}

enum GardenSound {
    private typealias Grains = SoundSynth.Grains
    private typealias Wash = SoundSynth.Wash
    private typealias Ring = SoundSynth.Ring
    private typealias Partial = SoundSynth.Ring.Partial
    private typealias Tone = SoundSynth.Tone
    private typealias Voice = SoundSynth.Voice

    static func design(for kind: FeedbackCue.Kind, random: inout SoundSynth.Random) -> SoundSynth.Design? {
        switch kind {
        case .tick: SoundSynth.Design(layers: [chirp(at: 0, pitch: random.between(3000...4000), gain: 0.5, random: &random)], level: -30)
        case .dayTick: cuckoo(&random)
        case .press: rustle(&random)
        case .release: bud(&random)
        case .pop: bloom(&random)
        case .snap: tweet(&random)
        case .inflate: morning(&random)
        case .carve: swish(&random)
        }
    }

    static func contextual(_ kind: FeedbackCue.Kind, _ context: CueContext, random: inout SoundSynth.Random) -> SoundSynth.Design? {
        switch (kind, context.surface) {
        case (.press, .land): rustle(&random)
        case (.press, .sea): plip(&random)
        default: nil
        }
    }

    private static func chirp(at time: Double, pitch: Double, gain: Double, random: inout SoundSynth.Random) -> Tone {
        Tone(
            voice: Voice(
                startFrequency: pitch,
                endFrequency: pitch * random.between(1.35...1.6),
                glide: random.between(0.01...0.016),
                vibratoDepth: 0.03,
                vibratoRate: random.between(55...75),
                vibratoDecay: 0.05,
                attack: 0.003,
                decay: random.between(0.018...0.028),
                duration: 0.07,
                gain: gain,
                overtone: 0.05
            ),
            at: time
        )
    }

    private static func pluck(at time: Double, pitch: Double, gain: Double, random: inout SoundSynth.Random) -> [any SoundLayer] {
        [
            Wash(at: time, attack: 0.0002, decay: 0.0015, frequency: min(pitch * 4, 7000), resonance: 0.7, gain: gain * 0.25),
            Ring(at: time, partials: [
                Partial(frequency: pitch, decay: random.between(0.3...0.4), gain: gain),
                Partial(frequency: pitch * 2.76, decay: 0.1, gain: gain * 0.3),
                Partial(frequency: pitch * 5.4, decay: 0.04, gain: gain * 0.12),
            ]),
        ]
    }

    private static func rustle(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.004, decay: 0.03, frequency: random.between(170...230), resonance: 0.8, gain: 0.35),
                Grains(rise: 0.006, fall: 0.045, density: random.between(450...650), band: 1500...6000, cycles: 1...2, resonance: 0.8, grit: 1.5, gain: 0.8),
            ],
            level: -25
        )
    }

    private static func plip(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = random.between(550...700)
        return SoundSynth.Design(
            layers: [
                Tone(voice: Voice(startFrequency: pitch, endFrequency: pitch * random.between(2.2...2.6), glide: 0.008, attack: 0.001, decay: 0.03, duration: 0.08, gain: 0.6, overtone: 0), at: 0),
                Ring(at: 0.004, partials: [Partial(frequency: pitch * 2.1, decay: 0.04, gain: 0.25)]),
                Wash(attack: 0.0005, decay: 0.01, frequency: 3500, resonance: 0.7, gain: 0.15),
            ],
            level: -24,
            floor: 300
        )
    }

    private static func bud(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = random.between(850...1050)
        return SoundSynth.Design(
            layers: [
                Tone(voice: Voice(startFrequency: pitch, endFrequency: pitch * 1.4, glide: 0.01, attack: 0.001, decay: 0.02, duration: 0.06, gain: 0.4, overtone: 0.1), at: 0),
                Wash(attack: 0.0005, decay: 0.006, frequency: 2500, resonance: 0.8, gain: 0.2),
            ],
            level: -28
        )
    }

    private static func bloom(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let notes = [784.0, 880.0, 1046.5, 1174.7, 1318.5]
        let first = Int.random(in: 0...2, using: &random)
        var layers = pluck(at: 0, pitch: notes[first] * random.between(0.997...1.003), gain: 0.4, random: &random)
        layers += pluck(at: random.between(0.07...0.09), pitch: notes[first + 2] * random.between(0.997...1.003), gain: 0.6, random: &random)
        return SoundSynth.Design(layers: layers, level: -20)
    }

    private static func cuckoo(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = random.between(690...730)
        return SoundSynth.Design(
            layers: [
                Tone(voice: Voice(startFrequency: pitch * 1.03, endFrequency: pitch, glide: 0.02, attack: 0.015, decay: 0.12, duration: 0.18, gain: 0.5, overtone: 0.12), at: 0),
                Tone(voice: Voice(startFrequency: pitch * 0.84, endFrequency: pitch * 0.8, glide: 0.03, attack: 0.02, decay: 0.18, duration: 0.3, gain: 0.5, overtone: 0.12), at: 0.24),
            ],
            level: -22
        )
    }

    private static func tweet(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = random.between(2600...3000)
        return SoundSynth.Design(
            layers: [
                chirp(at: 0, pitch: pitch, gain: 0.5, random: &random),
                chirp(at: random.between(0.1...0.12), pitch: pitch * 1.25, gain: 0.6, random: &random),
            ],
            level: -24
        )
    }

    private static func morning(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers: [any SoundLayer] = [
            Wash(attack: 0.25, decay: 0.25, frequency: 900, sweep: 1.8, resonance: 0.6, gain: 0.05),
        ]
        let pitch = random.between(3200...3600)
        let steps = [1.0, 0.9, 1.12, 0.82]
        var time = 0.05
        for step in steps {
            layers.append(chirp(at: time, pitch: pitch * step, gain: random.between(0.4...0.6), random: &random))
            time += random.between(0.09...0.13)
        }
        layers += pluck(at: time + 0.05, pitch: 1046.5 * random.between(0.998...1.002), gain: 0.35, random: &random)
        return SoundSynth.Design(layers: layers, level: -21)
    }

    private static func swish(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.003, decay: 0.015, frequency: 4000, resonance: 0.6, gain: 0.1),
                Grains(rise: 0.004, fall: 0.02, density: random.between(600...800), band: 2000...7000, cycles: 1...2, resonance: 0.8, grit: 1.8, gain: 0.6),
            ],
            level: -29
        )
    }
}
