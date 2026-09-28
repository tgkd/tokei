import Foundation

extension SoundTimbre {
    static let glass = SoundTimbre(id: "ice", variants: [.press: 12, .pop: 10]) { kind, random in
        IceSound.design(for: kind, random: &random)
    }
}

enum IceSound {
    private typealias Grains = SoundSynth.Grains
    private typealias Wash = SoundSynth.Wash
    private typealias Ring = SoundSynth.Ring
    private typealias Partial = SoundSynth.Ring.Partial
    private typealias Tone = SoundSynth.Tone
    private typealias Voice = SoundSynth.Voice

    private static let notes = [1318.5, 1480.0, 1661.2, 1975.5, 2217.5, 2637.0, 2960.0, 3322.4, 3951.1, 4434.9, 5274.0]
    private static let sheet = [1, 1.47, 2.09, 2.56, 3.03]

    static func design(for kind: FeedbackCue.Kind, random: inout SoundSynth.Random) -> SoundSynth.Design? {
        let designs: [FeedbackCue.Kind: (inout SoundSynth.Random) -> SoundSynth.Design] = [
            .tick: tick,
            .dayTick: chime,
            .press: footstep,
            .release: lift,
            .pop: shatter,
            .snap: snap,
            .inflate: frost,
            .carve: scuff,
        ]
        return designs[kind]?(&random)
    }

    private static func note(_ range: ClosedRange<Int>, _ random: inout SoundSynth.Random) -> Double {
        notes[Int.random(in: range, using: &random)] * random.between(0.996...1.004)
    }

    private static func crunch(at time: Double, rise: Double, fall: Double, weight: Double, band: ClosedRange<Double>, random: inout SoundSynth.Random) -> [any SoundLayer] {
        [
            Grains(at: time, rise: rise, fall: fall, density: random.between(1000...1600), band: band, cycles: 3...7, resonance: 2, grit: 1.5, gain: weight),
            Grains(at: time, rise: rise, fall: fall * 0.8, density: random.between(150...300), band: 1200...8000, cycles: 1...3, resonance: 0.9, grit: 2.5, gain: weight * 0.55),
            Grains(at: time, rise: rise, fall: fall, density: 1500, band: 2500...9000, cycles: 2...5, resonance: 1, grit: 1.5, gain: weight * 0.12),
        ]
    }

    private static func tinkle(at time: Double, pitch: Double, gain: Double, random: inout SoundSynth.Random) -> [any SoundLayer] {
        [
            Wash(at: time, attack: 0.0003, decay: 0.0025, frequency: random.between(700...1100), resonance: 0.9, gain: gain * 0.5),
            Wash(at: time, attack: 0.0001, decay: 0.0004, frequency: 7000, resonance: 0.8, gain: gain * 0.4),
            Ring(at: time, partials: [
                Partial(frequency: pitch, decay: random.between(0.015...0.03), gain: gain),
                Partial(frequency: pitch * 2.756, decay: 0.008, gain: gain * 0.3),
            ]),
        ]
    }

    private static func tick(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = 3700 * random.between(0.97...1.03)
        return SoundSynth.Design(
            layers: [
                Wash(attack: 0.0001, decay: 0.0004, frequency: 6000, resonance: 0.8, gain: 0.15),
                Ring(partials: [
                    Partial(frequency: pitch, decay: random.between(0.005...0.008), gain: 0.5),
                    Partial(frequency: pitch * 2.756, decay: 0.003, gain: 0.12),
                ]),
            ],
            level: -30
        )
    }

    private static func chime(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = note(0...2, &random)
        return SoundSynth.Design(
            layers: [
                Wash(attack: 0.0001, decay: 0.0006, frequency: 5000, resonance: 0.7, gain: 0.35),
                Wash(attack: 0.0004, decay: 0.006, frequency: random.between(600...800), resonance: 0.9, gain: 0.2),
                Ring(partials: [
                    Partial(frequency: pitch / 2, decay: 0.03, gain: 0.2),
                    Partial(frequency: pitch, decay: random.between(0.06...0.075), gain: 0.6, beat: random.between(1.5...3)),
                    Partial(frequency: pitch * 2.756, decay: 0.035, gain: 0.3),
                    Partial(frequency: pitch * 5.404, decay: 0.014, gain: 0.12),
                ]),
            ],
            level: -22
        )
    }

    private static func footstep(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let toe = random.between(0.09...0.14)
        var layers = crunch(at: 0, rise: random.between(0.01...0.018), fall: random.between(0.028...0.042), weight: 1, band: 350...1800, random: &random)
        layers += crunch(at: toe, rise: random.between(0.01...0.016), fall: random.between(0.022...0.035), weight: random.between(0.45...0.7), band: 400...2000, random: &random)
        layers.append(Wash(attack: 0.006, decay: 0.03, frequency: random.between(180...240), resonance: 0.8, gain: 0.15))
        return SoundSynth.Design(layers: layers, level: -21)
    }

    private static func scuff(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let delay = random.between(0...0.006)
        let rise = random.between(0.002...0.004)
        let fall = random.between(0.008...0.013)
        return SoundSynth.Design(
            layers: [
                Grains(at: delay, rise: rise, fall: fall, density: random.between(3000...4000), band: 450...2600, cycles: 2...4, resonance: 1.3, grit: 1.2, gain: 1),
                Grains(at: delay, rise: rise, fall: fall * 0.8, density: random.between(300...500), band: 1500...8000, cycles: 1...3, resonance: 0.9, grit: 2, gain: 0.5),
                Grains(at: delay, rise: rise, fall: fall, density: 2000, band: 2500...9000, cycles: 2...5, resonance: 1, grit: 1.5, gain: 0.15),
            ],
            level: -24
        )
    }

    private static func lift(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers: [any SoundLayer] = [
            Grains(rise: 0.015, fall: 0.04, density: random.between(250...400), band: 300...1400, cycles: 3...8, resonance: 2.5, grit: 2.2, gain: 0.7),
            Grains(rise: 0.015, fall: 0.05, density: random.between(80...160), band: 1500...8000, cycles: 1...3, resonance: 0.9, grit: 2.5, gain: 0.35),
            Wash(attack: 0.02, decay: 0.05, frequency: random.between(900...1300), sweep: 0.6, resonance: 0.7, gain: 0.12),
        ]
        var time = random.between(0.05...0.08)
        for index in 0..<Int.random(in: 1...2, using: &random) {
            layers += tinkle(at: time, pitch: note(6...10, &random), gain: 0.1 / Double(index + 1), random: &random)
            time += random.between(0.05...0.09)
        }
        return SoundSynth.Design(layers: layers, level: -23)
    }

    private static func shatter(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let base = random.between(1700...2400)
        var layers: [any SoundLayer] = [
            Wash(attack: 0.0001, decay: random.between(0.002...0.0035), frequency: 2800, resonance: 0.4, gain: 0.6),
            Wash(attack: 0.0005, decay: random.between(0.01...0.016), frequency: random.between(450...650), resonance: 0.8, gain: 0.3),
            Grains(at: 0.001, rise: 0.001, fall: random.between(0.01...0.014), density: 1400, band: 800...9000, cycles: 1...3, resonance: 0.9, grit: 1.5, gain: 0.8),
            Grains(at: 0.004, rise: 0.005, fall: random.between(0.04...0.07), density: random.between(400...600), band: 1500...9000, cycles: 1...3, resonance: 1.2, grit: 2.8, gain: 0.5),
            Ring(partials: sheet.map { ratio in
                Partial(
                    frequency: base * ratio * random.between(0.97...1.03),
                    decay: 0.06 / pow(ratio, 0.6) * random.between(0.8...1.2),
                    gain: random.between(0.4...1) / ratio.squareRoot() * 0.25
                )
            }),
        ]
        if random.chance(0.5) {
            layers.append(Tone(voice: Voice(startFrequency: random.between(6500...8000), endFrequency: random.between(1400...1800), glide: random.between(0.012...0.02), attack: 0.001, decay: 0.03, duration: 0.1, gain: 0.08, overtone: 0)))
        }
        var time = random.between(0.08...0.12)
        for index in 0..<Int.random(in: 3...5, using: &random) {
            let gain = 0.35 * pow(0.7, Double(index)) * random.between(0.7...1)
            let pitch = note(5...10, &random)
            layers += tinkle(at: time, pitch: pitch, gain: gain, random: &random)
            if random.chance(0.4) {
                layers += tinkle(at: time + random.between(0.03...0.06), pitch: pitch, gain: gain * 0.4, random: &random)
            }
            time += random.between(0.05...0.1)
        }
        return SoundSynth.Design(layers: layers, level: -18)
    }

    private static func snap(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = note(4...6, &random)
        var layers: [any SoundLayer] = [
            Wash(attack: 0.0001, decay: 0.002, frequency: 3500, resonance: 0.45, gain: 0.6),
            Wash(attack: 0.0005, decay: 0.01, frequency: random.between(550...750), resonance: 0.8, gain: 0.25),
            Grains(at: 0.0005, rise: 0.001, fall: 0.007, density: 1200, band: 1500...9000, cycles: 1...3, resonance: 1, grit: 1.8, gain: 0.6),
            Ring(partials: [
                Partial(frequency: pitch, decay: random.between(0.045...0.06), gain: 0.45),
                Partial(frequency: pitch * 2.756, decay: 0.022, gain: 0.25),
                Partial(frequency: pitch * 5.404, decay: 0.01, gain: 0.12),
            ]),
        ]
        if random.chance(0.5) {
            layers += tinkle(at: random.between(0.07...0.11), pitch: note(7...10, &random), gain: 0.12, random: &random)
        }
        return SoundSynth.Design(layers: layers, level: -21)
    }

    private static func frost(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers: [any SoundLayer] = [
            Wash(attack: 0.16, decay: 0.08, frequency: 2200, sweep: 2.2, resonance: 0.8, gain: 0.08),
            Wash(attack: 0.05, decay: 0.08, frequency: 420, sweep: 1.6, resonance: 1, gain: 0.08),
            Grains(rise: 0.22, fall: 0.07, density: 260, band: 1500...8000, cycles: 1...3, resonance: 1.2, grit: 2.5, gain: 0.45),
        ]
        let first = Int.random(in: 0...2, using: &random)
        let count = Int.random(in: 6...8, using: &random)
        for index in 0..<count {
            let progress = Double(index) / Double(count - 1)
            let pitch = notes[min(first + index, notes.count - 1)] * random.between(0.997...1.003)
            let gain = 0.15 + 0.2 * progress
            layers.append(Ring(at: 0.03 + 0.28 * pow(progress, 0.85) + random.between(-0.008...0.008), partials: [
                Partial(frequency: pitch, decay: random.between(0.05...0.08), gain: gain),
                Partial(frequency: pitch * 2.756, decay: 0.02, gain: gain * 0.25),
            ]))
        }
        let top = notes[min(first + count, notes.count - 1)]
        layers.append(Ring(at: 0.34, partials: [
            Partial(frequency: top, decay: 0.1, gain: 0.35, beat: 2),
            Partial(frequency: top * 1.5, decay: 0.08, gain: 0.18, beat: 3),
        ]))
        return SoundSynth.Design(layers: layers, level: -19)
    }
}
