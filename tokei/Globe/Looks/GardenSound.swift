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
        case .tick: bamboo(&random)
        case .dayTick: shishi(&random)
        case .press: crunch(&random)
        case .release: pebbles(&random)
        case .pop: drop(&random)
        case .snap: clappers(&random)
        case .inflate: suikinkutsu(&random)
        case .carve: rake(&random)
        }
    }

    static func contextual(_ kind: FeedbackCue.Kind, _ context: CueContext, random: inout SoundSynth.Random) -> SoundSynth.Design? {
        switch (kind, context.surface) {
        case (.press, .land): pat(&random)
        case (.press, .sea): crunch(&random)
        default: nil
        }
    }

    private static func crunch(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.002, decay: 0.02, frequency: 250, resonance: 0.9, gain: 0.4),
                Grains(rise: 0.008, fall: 0.04, density: random.between(400...700), band: 1200...5000, cycles: 1...3, resonance: 1.4, grit: 2.5, gain: 1),
            ],
            level: -22,
            floor: 100
        )
    }

    private static func pat(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.006, decay: 0.05, frequency: random.between(160...240), resonance: 0.8, gain: 0.6),
                Grains(rise: 0.006, fall: 0.05, density: 150, band: 2000...5000, cycles: 1...3, resonance: 0.9, grit: 1.5, gain: 0.15),
            ],
            level: -26
        )
    }

    private static func pebbles(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers: [any SoundLayer] = []
        let count = Int.random(in: 2...4, using: &random)
        for _ in 0..<count {
            layers.append(Ring(at: random.between(0.02...0.12), partials: [
                Partial(frequency: random.between(2200...4000), decay: random.between(0.008...0.015), gain: random.between(0.4...0.6)),
            ]))
        }
        return SoundSynth.Design(layers: layers, level: -30)
    }

    private static func drop(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.002, decay: 0.025, frequency: 150, resonance: 1, gain: 0.7),
                Grains(at: 0.01, rise: 0.005, fall: 0.05, density: 300, band: 1500...5000, cycles: 1...3, resonance: 1, grit: 2, gain: 0.6),
                Wash(at: 0.05, attack: 0.08, decay: 0.12, frequency: 2000, sweep: 2, resonance: 0.6, gain: 0.12),
            ],
            level: -21
        )
    }

    private static func rake(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers: [any SoundLayer] = [
            Wash(attack: 0.004, decay: 0.03, frequency: 3000, resonance: 0.5, gain: 0.12),
        ]
        let tines = Int.random(in: 3...5, using: &random)
        var offset = 0.0
        for _ in 0..<tines {
            layers.append(Grains(at: offset, rise: 0.003, fall: 0.015, density: 900, band: 1500...6000, cycles: 1...3, resonance: 1.2, grit: 2, gain: 0.6))
            offset += random.between(0.004...0.008)
        }
        return SoundSynth.Design(layers: layers, level: -26)
    }

    private static func bamboo(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = random.between(1100...1500)
        return SoundSynth.Design(
            layers: [
                Wash(attack: 0.0001, decay: 0.0005, frequency: 4000, resonance: 0.7, gain: 0.3),
                Ring(partials: [
                    Partial(frequency: pitch, decay: random.between(0.012...0.025), gain: 1),
                    Partial(frequency: pitch * 2.6, decay: 0.006, gain: 0.5),
                ]),
            ],
            level: -30
        )
    }

    private static func shishi(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.0001, decay: 0.001, frequency: 2500, resonance: 0.6, gain: 0.4),
                Ring(partials: [
                    Partial(frequency: 260 * random.between(0.98...1.02), decay: 0.09, gain: 1),
                    Partial(frequency: 550 * random.between(0.98...1.02), decay: 0.06, gain: 0.6),
                    Partial(frequency: 790 * random.between(0.98...1.02), decay: 0.04, gain: 0.4),
                    Partial(frequency: 1800 * random.between(0.98...1.02), decay: 0.015, gain: 0.4),
                    Partial(frequency: 3900 * random.between(0.98...1.02), decay: 0.008, gain: 0.25),
                ]),
                Grains(at: 0.12, rise: 0.02, fall: 0.08, density: 300, band: 2000...6000, cycles: 3...6, resonance: 3, grit: 2, gain: 0.25),
            ],
            level: -20
        )
    }

    private static func clappers(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers: [any SoundLayer] = []
        for strike in [0.0, 0.12] {
            layers.append(Wash(at: strike, attack: 0.0001, decay: 0.0006, frequency: 6000, resonance: 0.6, gain: 0.4))
            layers.append(Ring(at: strike, partials: [
                Partial(frequency: random.between(2000...2600), decay: random.between(0.03...0.06), gain: 1),
                Partial(frequency: random.between(5000...5600), decay: 0.015, gain: 0.5),
            ]))
        }
        return SoundSynth.Design(layers: layers, level: -19)
    }

    private static func suikinkutsu(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let layers: [any SoundLayer] = [
            Tone(voice: Voice(startFrequency: 1600, endFrequency: 2600, glide: 0.006, attack: 0.001, decay: 0.012, duration: 0.03, gain: 0.5, overtone: 0.1), at: 0),
            jar(at: 0.01, gain: 1, random: &random),
            jar(at: 0.45, gain: 0.4, random: &random),
            jar(at: 0.8, gain: 0.2, random: &random),
        ]
        return SoundSynth.Design(layers: layers, level: -22, floor: 400)
    }

    private static func jar(at time: Double, gain: Double, random: inout SoundSynth.Random) -> Ring {
        let frequencies = [850.0, 1375.0, 1650.0, 1900.0, 2250.0, 2863.0]
        let gains = [1.0, 0.7, 0.6, 0.5, 0.35, 0.25]
        return Ring(at: time, partials: frequencies.indices.map { index in
            Partial(
                frequency: frequencies[index] * random.between(0.98...1.02),
                decay: (1.8 - 0.8 * Double(index) / 5.0) * random.between(0.95...1.05),
                gain: gains[index] * gain * random.between(0.9...1.1),
                beat: index < 2 ? random.between(0.5...1.2) : 0.0
            )
        })
    }
}
