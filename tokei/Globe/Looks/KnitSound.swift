import Foundation

extension SoundTimbre {
    static let knit = SoundTimbre(
        id: "knit",
        variants: [.press: 10, .pop: 8, .release: 8],
        design: { kind, random in
            KnitSound.design(for: kind, random: &random)
        },
        contextual: { kind, context, random in
            KnitSound.contextual(kind, context, random: &random)
        },
        train: KnitSound.train
    )
}

enum KnitSound {
    private typealias Grains = SoundSynth.Grains
    private typealias Wash = SoundSynth.Wash
    private typealias Ring = SoundSynth.Ring
    private typealias Partial = SoundSynth.Ring.Partial

    static func design(for kind: FeedbackCue.Kind, random: inout SoundSynth.Random) -> SoundSynth.Design? {
        switch kind {
        case .tick: tick(&random)
        case .dayTick: clink(&random)
        case .press: thump(&random)
        case .release: exhale(&random)
        case .pop: pok(&random)
        case .snap: scissors(&random)
        case .inflate: fwump(&random)
        case .carve: stitch(&random)
        }
    }

    static func contextual(_ kind: FeedbackCue.Kind, _ context: CueContext, random: inout SoundSynth.Random) -> SoundSynth.Design? {
        if kind == .tick, context.direction == -1 {
            return unravel(&random)
        }
        return nil
    }

    static let train = SoundTrain(
        spacing: 0.35,
        limit: 12,
        haptics: 0,
        sharpness: 0.1,
        design: { _, random in
            SoundSynth.Design(
                layers: [
                    Wash(attack: 0.004, decay: 0.03, frequency: random.between(110...160), resonance: 0.8, gain: 0.8),
                    Grains(rise: 0.004, fall: 0.02, density: 160, band: 1500...4000, cycles: 1...2, resonance: 0.8, grit: 2, gain: 0.1),
                ],
                level: -28,
                floor: 70
            )
        }
    )

    private static func tick(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = random.chance(0.5) ? 1600.0 : 1900.0
        return SoundSynth.Design(
            layers: [
                Ring(partials: [
                    Partial(frequency: pitch, decay: 0.012, gain: 1),
                    Partial(frequency: pitch * 2.7, decay: 0.006, gain: 0.4),
                ]),
                Wash(attack: 0.0004, decay: 0.001, frequency: 5000, resonance: 0.7, gain: 0.3),
            ],
            level: -30
        )
    }

    private static func clink(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Ring(partials: [
                    Partial(frequency: 3100, decay: 0.06, gain: 1),
                    Partial(frequency: 7400, decay: 0.03, gain: 0.4),
                ]),
                Wash(attack: 0.0004, decay: 0.001, frequency: 5000, resonance: 0.7, gain: 0.3),
            ],
            level: -27
        )
    }

    private static func thump(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.006, decay: 0.06, frequency: random.between(140...220), resonance: 0.8, gain: 0.7),
                Grains(rise: 0.005, fall: 0.04, density: 300, band: 1500...4000, cycles: 1...2, resonance: 0.8, grit: 2, gain: 0.12),
            ],
            level: -24,
            floor: 70
        )
    }

    private static func exhale(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.03, decay: 0.09, frequency: 900, sweep: 0.55, resonance: 0.5, gain: 0.4),
                Grains(rise: 0.006, fall: 0.04, density: 160, band: 1500...4000, cycles: 1...2, resonance: 0.8, grit: 2, gain: 0.08),
            ],
            level: -28
        )
    }

    private static func pok(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = random.between(1500...2200)
        return SoundSynth.Design(
            layers: [
                Ring(partials: [
                    Partial(frequency: pitch, decay: 0.02, gain: 1),
                    Partial(frequency: pitch * 2.4, decay: 0.01, gain: 0.5),
                ]),
                Wash(attack: 0.001, decay: 0.01, frequency: 300, resonance: 0.9, gain: 0.5),
                Wash(at: 0.04, attack: 0.015, decay: 0.025, frequency: 800, sweep: 3.5, resonance: 0.7, gain: 0.3),
            ],
            level: -21
        )
    }

    private static func stitch(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.0003, decay: 0.001, frequency: 6000, resonance: 0.7, gain: 0.3),
                Ring(partials: [Partial(frequency: 5200, decay: 0.006, gain: 0.15)]),
                Wash(at: 0.01, attack: 0.01, decay: 0.03, frequency: 800, sweep: 3.75, resonance: 0.6, gain: 0.35),
            ],
            level: -27
        )
    }

    private static func unravel(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Grains(rise: 0.005, fall: 0.06, density: 900, band: 600...2500, cycles: 1...3, resonance: 1, grit: 1.2, gain: 0.8),
                Wash(attack: 0.005, decay: 0.05, frequency: 1800, sweep: 0.5, resonance: 0.7, gain: 0.2),
            ],
            level: -30
        )
    }

    private static func scissors(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Grains(rise: 0.002, fall: 0.02, density: 2000, band: 3000...8000, cycles: 2...4, resonance: 4, grit: 1.5, gain: 0.6),
                Ring(at: 0.03, partials: [Partial(frequency: 4200, decay: 0.008, gain: 0.5)]),
            ],
            level: -23
        )
    }

    private static func fwump(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers: [any SoundLayer] = [
            Wash(attack: 0.02, decay: 0.12, frequency: 120, resonance: 0.8, gain: 0.8),
            Wash(attack: 0.03, decay: 0.1, frequency: 1000, resonance: 0.5, gain: 0.15),
        ]
        for time in [0.25, 0.37, 0.49] {
            layers.append(Wash(at: time, attack: 0.0003, decay: 0.001, frequency: 6000, resonance: 0.7, gain: 0.3))
            layers.append(Ring(at: time, partials: [Partial(frequency: 5200, decay: 0.006, gain: 0.15)]))
        }
        return SoundSynth.Design(layers: layers, level: -21, floor: 70)
    }
}
