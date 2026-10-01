import Foundation

extension SoundTimbre {
    static let repeater = SoundTimbre(
        id: "repeater",
        variants: [.press: 10, .pop: 10],
        design: { kind, random in
            RepeaterSound.design(for: kind, random: &random)
        },
        contextual: { kind, context, random in
            RepeaterSound.contextual(for: kind, context: context, random: &random)
        },
        train: RepeaterSound.freewheel
    )
}

enum RepeaterSound {
    private typealias Grains = SoundSynth.Grains
    private typealias Wash = SoundSynth.Wash
    private typealias Ring = SoundSynth.Ring
    private typealias Partial = SoundSynth.Ring.Partial

    static let freewheel = SoundTrain(
        spacing: 0.16,
        limit: 24,
        haptics: 10,
        sharpness: 0.5,
        design: { speed, random in
            SoundSynth.Design(
                layers: ratchet(at: 0, gain: 0.35 + 0.3 * speed, random: &random),
                level: -28
            )
        }
    )

    static func design(for kind: FeedbackCue.Kind, random: inout SoundSynth.Random) -> SoundSynth.Design? {
        switch kind {
        case .tick: tick(&random)
        case .dayTick: ting(&random)
        case .press: crownPush(&random)
        case .release: detent(&random)
        case .pop: gongDesign(pitch: 523.25, gain: 0.55, random: &random)
        case .snap: snap(&random)
        case .inflate: wind(&random)
        case .carve: carve(&random)
        }
    }

    static func contextual(for kind: FeedbackCue.Kind, context: CueContext, random: inout SoundSynth.Random) -> SoundSynth.Design? {
        switch kind {
        case .pop:
            let semitones = Double(context.pitch ?? 0)
            return gongDesign(pitch: 523.25 * pow(2, semitones / 12), gain: 0.55, random: &random)
        default:
            return nil
        }
    }

    static func strike(hour: Int, minute: Int) -> SoundSequence {
        let hours = hour % 12 == 0 ? 12 : hour % 12
        let quarters = minute / 15
        let minutes = minute % 15
        let low = 220.0
        let high = 587.33
        var entries: [SoundSequence.Entry] = []
        var time = 0.0
        for _ in 0..<hours {
            entries.append(gongEntry(at: time, pitch: low, gain: 0.6))
            time += 0.55
        }
        for _ in 0..<quarters {
            entries.append(gongEntry(at: time, pitch: low, gain: 0.45))
            entries.append(gongEntry(at: time + 0.18, pitch: high, gain: 0.45))
            time += 0.5
        }
        for _ in 0..<minutes {
            entries.append(gongEntry(at: time, pitch: high, gain: 0.4))
            time += 0.3
        }
        return SoundSequence(entries: entries, seed: 0x5EED)
    }

    static func strikeDuration(hour: Int, minute: Int) -> Double {
        let hours = hour % 12 == 0 ? 12 : hour % 12
        let quarters = minute / 15
        let minutes = minute % 15
        let total = Double(hours) * 0.55 + Double(quarters) * 0.5 + Double(minutes) * 0.3
        return total + 3.4
    }

    private static func gongEntry(at time: Double, pitch: Double, gain: Double) -> SoundSequence.Entry {
        SoundSequence.Entry(
            at: time,
            design: { random in
                gongDesign(pitch: pitch, gain: gain, random: &random)
            },
            haptic: SoundSequence.HapticTick(intensity: 0.45, sharpness: 0.35)
        )
    }

    private static func gongDesign(pitch: Double, gain: Double, random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(layers: gong(at: 0, pitch: pitch, gain: gain, random: &random), level: -18, floor: 80)
    }

    private static func gong(at time: Double, pitch: Double, gain: Double, random: inout SoundSynth.Random) -> [any SoundLayer] {
        [
            Wash(at: time, attack: 0.0004, decay: 0.004, frequency: random.between(1200...1800), resonance: 0.6, gain: gain * 0.3),
            Wash(at: time, attack: 0.001, decay: 0.04, frequency: pitch * 0.5, resonance: 0.9, gain: gain * 0.14),
            Ring(at: time, partials: [1, 1.93, 2.76, 3.94, 5.1].map { ratio in
                Partial(
                    frequency: pitch * ratio * random.between(0.996...1.004),
                    decay: 0.55 / pow(ratio, 0.6) * random.between(0.85...1.15),
                    gain: gain / ratio.squareRoot() * random.between(0.8...1.1),
                    beat: ratio > 1 ? random.between(0.5...2.5) : 0
                )
            }),
        ]
    }

    private static func ratchet(at time: Double, gain: Double, random: inout SoundSynth.Random) -> [any SoundLayer] {
        [
            Wash(at: time, attack: 0.0001, decay: 0.0008, frequency: random.between(2600...3400), resonance: 0.7, gain: gain * 0.5),
            Ring(at: time, partials: [
                Partial(frequency: random.between(2100...2500), decay: 0.008, gain: gain * 0.5),
                Partial(frequency: random.between(4300...5200), decay: 0.003, gain: gain * 0.2),
            ]),
        ]
    }

    private static func tick(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(layers: ratchet(at: 0, gain: 0.7, random: &random), level: -31)
    }

    private static func ting(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = 987.77 * random.between(0.998...1.002)
        return SoundSynth.Design(layers: gong(at: 0, pitch: pitch, gain: 0.5, random: &random), level: -24)
    }

    private static func crownPush(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.004, decay: 0.04, frequency: random.between(160...220), resonance: 1, gain: 0.6),
                Wash(attack: 0.0001, decay: 0.0012, frequency: random.between(2400...3000), resonance: 0.6, gain: 0.4),
                Grains(rise: 0.004, fall: 0.02, density: 900, band: 400...2600, cycles: 1...3, resonance: 1.2, grit: 1.6, gain: 0.6),
            ],
            level: -23,
            floor: 110
        )
    }

    private static func detent(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.0001, decay: 0.0012, frequency: random.between(2600...3200), resonance: 0.7, gain: 0.55),
                Ring(partials: [
                    Partial(frequency: random.between(1800...2200), decay: 0.012, gain: 0.5),
                    Partial(frequency: random.between(3600...4200), decay: 0.005, gain: 0.25),
                ]),
            ],
            level: -28
        )
    }

    private static func snap(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(layers: ratchet(at: 0, gain: 0.8, random: &random), level: -27)
    }

    private static func wind(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers: [any SoundLayer] = [
            Wash(attack: 0.14, decay: 0.12, frequency: random.between(120...160), sweep: 2, resonance: 0.9, gain: 0.3),
            Grains(rise: 0.2, fall: 0.08, density: 300, band: 400...3200, cycles: 2...4, resonance: 1.3, grit: 2, gain: 0.5),
        ]
        for index in 0..<3 {
            layers += ratchet(at: 0.02 + 0.05 * Double(index), gain: 0.4, random: &random)
        }
        layers.append(Ring(at: 0.24, partials: [
            Partial(frequency: 1318.5, decay: 0.3, gain: 0.28, beat: 2),
            Partial(frequency: 1318.5 * 2.76, decay: 0.12, gain: 0.1),
        ]))
        return SoundSynth.Design(layers: layers, level: -19, floor: 70)
    }

    private static func carve(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(layers: ratchet(at: 0, gain: 0.45, random: &random), level: -29)
    }
}
