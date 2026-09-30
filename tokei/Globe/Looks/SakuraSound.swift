import Foundation

extension SoundTimbre {
    static let sakura = SoundTimbre(id: "sakura", variants: [.press: 10, .pop: 10], silent: [.carve]) { kind, random in
        SakuraSound.design(for: kind, random: &random)
    }
}

enum SakuraSound {
    private typealias Wash = SoundSynth.Wash
    private typealias Ring = SoundSynth.Ring
    private typealias Partial = SoundSynth.Ring.Partial

    private static let scale = [329.63, 349.23, 440.0, 493.88, 523.25, 659.26, 698.46, 880.0, 987.77, 1046.5, 1318.51, 1396.91]

    static func design(for kind: FeedbackCue.Kind, random: inout SoundSynth.Random) -> SoundSynth.Design? {
        let designs: [FeedbackCue.Kind: (inout SoundSynth.Random) -> SoundSynth.Design] = [
            .tick: tick,
            .dayTick: rin,
            .press: press,
            .release: release,
            .pop: pop,
            .snap: snap,
            .inflate: bloom,
        ]
        return designs[kind]?(&random)
    }

    private static func note(_ range: ClosedRange<Int>, _ random: inout SoundSynth.Random) -> Double {
        scale[Int.random(in: range, using: &random)] * random.between(0.997...1.003)
    }

    private static func pluck(at time: Double, pitch: Double, gain: Double, ring: Double, random: inout SoundSynth.Random) -> [any SoundLayer] {
        let harmonics = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
        let weights = [1.0, 0.55, 0.32, 0.2, 0.12, 0.07]
        return [
            Wash(at: time, attack: 0.0002, decay: 0.0018, frequency: min(pitch * 6, 7000), resonance: 0.7, gain: gain * 0.35),
            Wash(at: time, attack: 0.001, decay: 0.012, frequency: random.between(220...300), resonance: 0.9, gain: gain * 0.12),
            Ring(at: time, partials: zip(harmonics, weights).map { harmonic, weight in
                Partial(
                    frequency: pitch * harmonic * (1 + 0.0009 * harmonic * harmonic),
                    decay: ring / pow(harmonic, 0.75) * random.between(0.9...1.1),
                    gain: gain * weight * random.between(0.85...1.1)
                )
            }),
        ]
    }

    private static func tick(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Wash(attack: 0.0001, decay: 0.0012, frequency: random.between(2200...2600), resonance: 0.9, gain: 0.4),
                Ring(partials: [Partial(frequency: random.between(1500...1650), decay: 0.008, gain: 0.3)]),
            ],
            level: -31
        )
    }

    private static func rin(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let pitch = scale[10] * random.between(0.998...1.002)
        return SoundSynth.Design(
            layers: [
                Wash(attack: 0.0002, decay: 0.002, frequency: 4200, resonance: 0.6, gain: 0.3),
                Ring(partials: [
                    Partial(frequency: pitch, decay: random.between(0.28...0.34), gain: 0.5, beat: random.between(1.5...2.5)),
                    Partial(frequency: pitch * 2.71, decay: 0.12, gain: 0.2),
                    Partial(frequency: pitch * 5.2, decay: 0.05, gain: 0.08),
                ]),
            ],
            level: -25
        )
    }

    private static func press(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(layers: pluck(at: 0, pitch: note(0...4, &random), gain: 0.6, ring: random.between(0.22...0.3), random: &random), level: -22)
    }

    private static func release(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(layers: pluck(at: 0, pitch: note(5...8, &random), gain: 0.4, ring: random.between(0.16...0.22), random: &random), level: -25)
    }

    private static func pop(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let main = Int.random(in: 6...9, using: &random)
        var layers = pluck(at: 0, pitch: scale[main - 1] * random.between(0.997...1.003), gain: 0.28, ring: 0.08, random: &random)
        layers += pluck(at: random.between(0.045...0.065), pitch: scale[main] * random.between(0.997...1.003), gain: 0.6, ring: random.between(0.3...0.4), random: &random)
        return SoundSynth.Design(layers: layers, level: -19)
    }

    private static func snap(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers = pluck(at: 0, pitch: scale[7] * random.between(0.998...1.002), gain: 0.55, ring: 0.28, random: &random)
        layers += pluck(at: 0, pitch: scale[2] * random.between(0.998...1.002), gain: 0.25, ring: 0.3, random: &random)
        return SoundSynth.Design(layers: layers, level: -21)
    }

    private static func bloom(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        var layers: [any SoundLayer] = [
            Wash(attack: 0.22, decay: 0.12, frequency: 1800, sweep: 2.4, resonance: 0.6, gain: 0.07),
        ]
        let start = Int.random(in: 4...6, using: &random)
        for index in 0..<3 {
            let pitch = scale[min(start + index * 2, scale.count - 1)] * random.between(0.998...1.002)
            layers += pluck(at: 0.04 + Double(index) * random.between(0.085...0.1), pitch: pitch, gain: 0.35 + 0.1 * Double(index), ring: 0.3, random: &random)
        }
        let bell = scale[11] * random.between(0.998...1.002)
        layers.append(Ring(at: 0.34, partials: [
            Partial(frequency: bell, decay: 0.45, gain: 0.25, beat: random.between(2...3.5)),
            Partial(frequency: bell * 2.76, decay: 0.16, gain: 0.08),
        ]))
        return SoundSynth.Design(layers: layers, level: -20)
    }
}
