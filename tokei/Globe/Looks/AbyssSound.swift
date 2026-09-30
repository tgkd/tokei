import Foundation

extension SoundTimbre {
    static let abyss = SoundTimbre(id: "abyss", variants: [.press: 10, .pop: 8, .release: 8]) { kind, random in
        AbyssSound.design(for: kind, random: &random)
    }
}

enum AbyssSound {
    private typealias Grains = SoundSynth.Grains
    private typealias Wash = SoundSynth.Wash
    private typealias Ring = SoundSynth.Ring
    private typealias Partial = SoundSynth.Ring.Partial
    private typealias Tone = SoundSynth.Tone
    private typealias Voice = SoundSynth.Voice

    private static let pings = [1046.5, 1174.7, 1318.5, 1568.0, 1760.0]

    static func design(for kind: FeedbackCue.Kind, random: inout SoundSynth.Random) -> SoundSynth.Design? {
        let designs: [FeedbackCue.Kind: (inout SoundSynth.Random) -> SoundSynth.Design] = [
            .tick: drip,
            .dayTick: sounding,
            .press: bloop,
            .release: rise,
            .pop: sonar,
            .snap: resurface,
            .inflate: swell,
            .carve: fizz,
        ]
        return designs[kind]?(&random)
    }

    private static func bubble(at time: Double, pitch: Double, length: Double, gain: Double) -> Tone {
        Tone(
            voice: Voice(
                startFrequency: pitch * 0.55,
                endFrequency: pitch,
                glide: length * 0.22,
                attack: 0.0015,
                decay: length * 0.35,
                duration: length,
                gain: gain,
                overtone: 0.04
            ),
            at: time
        )
    }

    private static func drip(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = random.between(1500...2100)
        return SoundSynth.Design(
            layers: [
                bubble(at: 0, pitch: pitch, length: 0.035, gain: 0.5),
                Wash(attack: 0.0002, decay: 0.0012, frequency: 3200, resonance: 0.9, gain: 0.08),
            ],
            level: -31
        )
    }

    private static func sounding(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = pings[Int.random(in: 0...1, using: &random)] * random.between(0.997...1.003)
        return SoundSynth.Design(
            layers: [
                Wash(attack: 0.0003, decay: 0.002, frequency: 2400, resonance: 0.8, gain: 0.2),
                Ring(partials: [
                    Partial(frequency: pitch, decay: random.between(0.07...0.09), gain: 0.55, beat: random.between(1.2...2.2)),
                    Partial(frequency: pitch * 2.01, decay: 0.03, gain: 0.08),
                ]),
            ],
            level: -25
        )
    }

    private static func bloop(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = random.between(360...520)
        var layers: [any SoundLayer] = [
            bubble(at: 0, pitch: pitch, length: 0.11, gain: 0.8),
            Wash(attack: 0.004, decay: 0.03, frequency: random.between(260...340), resonance: 0.7, gain: 0.12),
            Grains(at: 0.012, rise: 0.01, fall: 0.035, density: random.between(60...110), band: 900...3200, cycles: 3...7, resonance: 3, grit: 1.6, gain: 0.25),
        ]
        if random.chance(0.6) {
            layers.append(bubble(at: random.between(0.05...0.08), pitch: pitch * random.between(1.6...2.1), length: 0.05, gain: 0.25))
        }
        return SoundSynth.Design(layers: layers, level: -22, floor: 120)
    }

    private static func rise(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers: [any SoundLayer] = []
        var time = 0.0
        var pitch = random.between(700...900)
        for index in 0..<Int.random(in: 3...5, using: &random) {
            layers.append(bubble(at: time, pitch: pitch, length: random.between(0.035...0.05), gain: 0.5 * pow(0.8, Double(index))))
            time += random.between(0.03...0.055)
            pitch *= random.between(1.12...1.3)
        }
        layers.append(Grains(rise: 0.02, fall: 0.05, density: random.between(80...140), band: 1500...5000, cycles: 3...6, resonance: 3, grit: 1.8, gain: 0.18))
        return SoundSynth.Design(layers: layers, level: -25)
    }

    private static func sonar(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = pings[Int.random(in: 1...4, using: &random)] * random.between(0.997...1.003)
        let echo = random.between(0.17...0.22)
        return SoundSynth.Design(
            layers: [
                Wash(attack: 0.0004, decay: 0.003, frequency: 1800, resonance: 0.7, gain: 0.3),
                bubble(at: 0, pitch: random.between(500...650), length: 0.07, gain: 0.35),
                Ring(partials: [
                    Partial(frequency: pitch, decay: random.between(0.16...0.2), gain: 0.55, beat: random.between(0.8...1.6)),
                    Partial(frequency: pitch * 2.0, decay: 0.05, gain: 0.08),
                    Partial(frequency: pitch * 0.5, decay: 0.08, gain: 0.12),
                ]),
                Ring(at: echo, partials: [
                    Partial(frequency: pitch * 0.998, decay: 0.16, gain: 0.2, beat: 1.1),
                ]),
                Ring(at: echo * 2, partials: [
                    Partial(frequency: pitch * 0.996, decay: 0.14, gain: 0.07, beat: 0.9),
                ]),
                Grains(at: 0.02, rise: 0.04, fall: 0.12, density: random.between(40...80), band: 1200...4000, cycles: 3...6, resonance: 3, grit: 1.8, gain: 0.15),
            ],
            level: -20
        )
    }

    private static func resurface(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = random.between(620...760)
        return SoundSynth.Design(
            layers: [
                bubble(at: 0, pitch: pitch, length: 0.06, gain: 0.55),
                bubble(at: random.between(0.05...0.07), pitch: pitch * 1.5, length: 0.07, gain: 0.45),
                Ring(at: 0.06, partials: [
                    Partial(frequency: pings[0] * 2, decay: 0.05, gain: 0.12),
                ]),
            ],
            level: -23
        )
    }

    private static func swell(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers: [any SoundLayer] = [
            Wash(attack: 0.22, decay: 0.12, frequency: 260, sweep: 2.4, resonance: 0.9, gain: 0.18),
            Wash(attack: 0.12, decay: 0.1, frequency: 1600, sweep: 1.6, resonance: 0.7, gain: 0.04),
            Tone(voice: Voice(startFrequency: 70, endFrequency: 190, glide: 0.16, attack: 0.08, decay: 0.2, duration: 0.55, gain: 0.35, overtone: 0.12)),
            Grains(at: 0.12, rise: 0.12, fall: 0.12, density: random.between(90...140), band: 900...4200, cycles: 3...7, resonance: 3, grit: 1.6, gain: 0.25),
        ]
        var time = random.between(0.2...0.26)
        var pitch = random.between(800...1000)
        for index in 0..<4 {
            layers.append(bubble(at: time, pitch: pitch, length: 0.045, gain: 0.3 * pow(0.8, Double(index))))
            time += random.between(0.04...0.07)
            pitch *= random.between(1.1...1.25)
        }
        layers.append(Ring(at: time + 0.02, partials: [
            Partial(frequency: pings[2], decay: 0.18, gain: 0.25, beat: 1.2),
        ]))
        return SoundSynth.Design(layers: layers, level: -21, floor: 60)
    }

    private static func fizz(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let delay = random.between(0...0.008)
        var layers: [any SoundLayer] = [
            Grains(at: delay, rise: 0.006, fall: random.between(0.012...0.02), density: random.between(900...1400), band: 2500...9000, cycles: 2...5, resonance: 2, grit: 1.8, gain: 0.5),
            Grains(at: delay, rise: 0.004, fall: 0.015, density: random.between(60...120), band: 900...2600, cycles: 4...8, resonance: 4, grit: 1.4, gain: 0.3),
        ]
        if random.chance(0.35) {
            layers.append(bubble(at: delay + random.between(0.005...0.02), pitch: random.between(1300...1900), length: 0.03, gain: 0.2))
        }
        return SoundSynth.Design(layers: layers, level: -29)
    }
}
