import Foundation

extension SoundTimbre {
    static let magma = SoundTimbre(id: "magma", variants: [.press: 10, .pop: 10]) { kind, random in
        MagmaSound.design(for: kind, random: &random)
    }
}

enum MagmaSound {
    private typealias Grains = SoundSynth.Grains
    private typealias Wash = SoundSynth.Wash
    private typealias Ring = SoundSynth.Ring
    private typealias Partial = SoundSynth.Ring.Partial
    private typealias Tone = SoundSynth.Tone
    private typealias Voice = SoundSynth.Voice

    static func design(for kind: FeedbackCue.Kind, random: inout SoundSynth.Random) -> SoundSynth.Design? {
        switch kind {
        case .tick: tick(&random)
        case .dayTick: knock(&random)
        case .press: crunch(&random)
        case .release: sizzle(&random)
        case .pop: blorp(&random)
        case .snap: clack(&random)
        case .inflate: forge(&random)
        case .carve: grind(&random)
        }
    }

    private static func crackle(at time: Double, rise: Double, fall: Double, density: Double, gain: Double) -> Grains {
        Grains(at: time, rise: rise, fall: fall, density: density, band: 800...6500, cycles: 1...3, resonance: 0.9, grit: 2.8, gain: gain)
    }

    private static func steam(at time: Double, attack: Double, decay: Double, gain: Double, random: inout SoundSynth.Random) -> Wash {
        Wash(at: time, attack: attack, decay: decay, frequency: random.between(3800...5200), sweep: random.between(0.55...0.75), resonance: 0.5, gain: gain)
    }

    private static func bubble(at time: Double, from low: Double, to high: Double, size: Double, gain: Double) -> Tone {
        Tone(voice: Voice(startFrequency: low, endFrequency: high, glide: 0.035 * size, attack: 0.004, decay: 0.05 * size, duration: 0.2 * size, gain: gain, overtone: 0.16), at: time)
    }

    private static func stone(at time: Double, pitch: Double, decay: Double, gain: Double, random: inout SoundSynth.Random) -> Ring {
        Ring(at: time, partials: [1, 2.31, 5.07, 7.43].map { ratio in
            Partial(
                frequency: pitch * ratio * random.between(0.97...1.03),
                decay: decay / pow(ratio, 0.7) * random.between(0.85...1.15),
                gain: gain / ratio.squareRoot() * random.between(0.7...1)
            )
        })
    }

    private static func tick(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.0001, decay: 0.0006, frequency: random.between(2300...2900), resonance: 0.7, gain: 0.35),
                Grains(rise: 0.0005, fall: 0.002, density: 2000, band: 1500...7000, cycles: 1...2, resonance: 0.9, grit: 1.5, gain: 0.3),
                stone(at: 0, pitch: random.between(900...1100), decay: 0.006, gain: 0.25, random: &random),
            ],
            level: -31
        )
    }

    private static func knock(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.0005, decay: 0.009, frequency: random.between(330...420), resonance: 1.1, gain: 0.5),
                Wash(attack: 0.0001, decay: 0.001, frequency: 2400, resonance: 0.6, gain: 0.3),
                stone(at: 0, pitch: random.between(240...290), decay: 0.024, gain: 0.45, random: &random),
                crackle(at: 0.004, rise: 0.003, fall: 0.02, density: random.between(120...220), gain: 0.35),
            ],
            level: -24,
            floor: 110
        )
    }

    private static func crunch(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.004, decay: random.between(0.045...0.06), frequency: random.between(150...210), resonance: 1, gain: 0.6),
                Grains(rise: random.between(0.006...0.01), fall: random.between(0.026...0.036), density: random.between(900...1300), band: 250...1600, cycles: 2...5, resonance: 1.6, grit: 1.4, gain: 1),
                Grains(rise: 0.005, fall: random.between(0.02...0.03), density: random.between(200...350), band: 1200...7000, cycles: 1...3, resonance: 0.9, grit: 2.4, gain: 0.45),
                steam(at: random.between(0.025...0.04), attack: 0.02, decay: 0.07, gain: 0.12, random: &random),
            ],
            level: -21,
            floor: 90
        )
    }

    private static func sizzle(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers: [any SoundLayer] = [
            steam(at: 0, attack: 0.012, decay: random.between(0.08...0.11), gain: 0.35, random: &random),
            crackle(at: 0.005, rise: 0.02, fall: random.between(0.06...0.09), density: random.between(90...160), gain: 0.6),
        ]
        if random.chance(0.7) {
            layers.append(bubble(at: random.between(0.015...0.04), from: random.between(210...250), to: random.between(360...420), size: 0.7, gain: 0.22))
        }
        return SoundSynth.Design(layers: layers, level: -24, floor: 100)
    }

    private static func blorp(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let low = random.between(145...185)
        let burst = random.between(0.045...0.06)
        var layers: [any SoundLayer] = [
            bubble(at: 0, from: low, to: low * random.between(2.4...2.8), size: 1.1, gain: 0.7),
            Wash(attack: 0.003, decay: 0.04, frequency: random.between(115...155), resonance: 1.1, gain: 0.55),
            Wash(at: burst, attack: 0.0005, decay: 0.012, frequency: random.between(900...1300), resonance: 0.7, gain: 0.35),
            Grains(at: burst + 0.005, rise: 0.01, fall: random.between(0.06...0.08), density: random.between(180...260), band: 800...6000, cycles: 1...3, resonance: 1, grit: 2.6, gain: 0.55),
            steam(at: burst + 0.03, attack: 0.03, decay: 0.1, gain: 0.12, random: &random),
        ]
        if random.chance(0.6) {
            let second = random.between(0.1...0.15)
            let pitch = random.between(220...260)
            layers.append(bubble(at: second, from: pitch, to: pitch * random.between(2.1...2.4), size: 0.7, gain: 0.3))
        }
        return SoundSynth.Design(layers: layers, level: -19, floor: 80)
    }

    private static func clack(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.0001, decay: 0.0015, frequency: 3000, resonance: 0.5, gain: 0.6),
                Wash(attack: 0.0005, decay: 0.018, frequency: random.between(200...240), resonance: 0.9, gain: 0.3),
                stone(at: 0, pitch: random.between(480...560), decay: 0.03, gain: 0.5, random: &random),
                crackle(at: 0.003, rise: 0.002, fall: 0.015, density: 300, gain: 0.3),
            ],
            level: -21,
            floor: 120
        )
    }

    private static func forge(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.18, decay: 0.2, frequency: random.between(95...120), sweep: 2.6, resonance: 1, gain: 0.5),
                Wash(attack: 0.12, decay: 0.16, frequency: random.between(520...640), sweep: 1.8, resonance: 0.6, gain: 0.2),
                crackle(at: 0, rise: 0.25, fall: 0.12, density: 350, gain: 0.8),
                bubble(at: random.between(0.2...0.24), from: random.between(110...130), to: random.between(280...320), size: 1.6, gain: 0.5),
                steam(at: 0.3, attack: 0.05, decay: 0.18, gain: 0.25, random: &random),
            ],
            level: -19,
            floor: 70
        )
    }

    private static func grind(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let delay = random.between(0...0.006)
        let rise = random.between(0.002...0.004)
        let fall = random.between(0.012...0.02)
        return SoundSynth.Design(
            layers: [
                Grains(at: delay, rise: rise, fall: fall, density: random.between(900...1400), band: 500...3200, cycles: 1...4, resonance: 1.2, grit: 1.8, gain: 1),
                Grains(at: delay, rise: rise, fall: fall * 1.3, density: random.between(150...300), band: 1500...7500, cycles: 1...2, resonance: 0.8, grit: 3, gain: 0.6),
                Wash(at: delay, attack: 0.004, decay: 0.02, frequency: random.between(4500...5500), resonance: 0.5, gain: 0.1),
            ],
            level: -25
        )
    }
}
