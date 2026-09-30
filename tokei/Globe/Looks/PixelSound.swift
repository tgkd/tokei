import Foundation

extension SoundTimbre {
    static let pixel = SoundTimbre(id: "pixel", variants: [.pop: 8, .press: 8, .inflate: 6]) { kind, random in
        PixelSound.design(for: kind, random: &random)
    }
}

enum PixelSound {
    private static let scale = [0, 2, 4, 7, 9]

    static func design(for kind: FeedbackCue.Kind, random: inout SoundSynth.Random) -> SoundSynth.Design? {
        let designs: [FeedbackCue.Kind: (inout SoundSynth.Random) -> SoundSynth.Design] = [
            .tick: tick,
            .dayTick: dayTick,
            .press: press,
            .release: release,
            .pop: coin,
            .snap: select,
            .inflate: powerUp,
            .carve: dig,
        ]
        return designs[kind]?(&random)
    }

    private static func note(_ octave: Int, _ step: Int) -> Double {
        let degree = ((step % scale.count) + scale.count) % scale.count
        let lift = (step - degree) / scale.count
        let semitones = Double(12 * (octave + lift - 4) + scale[degree] - 9)
        return 440 * pow(2, semitones / 12)
    }

    private static func tick(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Pulse(frequency: note(6, Int.random(in: 0...2, using: &random)), duty: 0.125, hold: 0.012, release: 0.01, gain: 0.5),
            ],
            level: -31
        )
    }

    private static func dayTick(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let root = Int.random(in: 0...1, using: &random)
        return SoundSynth.Design(
            layers: [
                Pulse(frequency: note(5, root), duty: 0.25, hold: 0.04, release: 0.015, gain: 0.5),
                Pulse(at: 0.055, frequency: note(5, root + 3), duty: 0.25, hold: 0.07, release: 0.04, gain: 0.5),
            ],
            level: -24
        )
    }

    private static func press(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let start = random.between(300...380)
        return SoundSynth.Design(
            layers: [
                Pulse(frequency: start, target: start * 0.33, slide: 0.07, duty: 0.25, hold: 0.05, release: 0.04, gain: 0.55),
                Noise(clock: random.between(9000...14000), hold: 0.012, release: 0.025, gain: 0.3),
            ],
            level: -21,
            floor: 80
        )
    }

    private static func release(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let start = random.between(200...250)
        return SoundSynth.Design(
            layers: [
                Pulse(frequency: start, target: start * 3, slide: 0.09, duty: 0.5, hold: 0.09, release: 0.05, gain: 0.5, vibrato: 0.02, vibratoRate: 18),
            ],
            level: -23
        )
    }

    private static func coin(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let first = note(5, Int.random(in: 2...4, using: &random))
        let second = first * pow(2, 5.0 / 12)
        return SoundSynth.Design(
            layers: [
                Pulse(frequency: first, duty: 0.5, hold: 0.065, release: 0.005, gain: 0.5),
                Pulse(at: 0.07, frequency: second, duty: 0.5, hold: 0.2, release: 0.16, gain: 0.5),
                Pulse(at: 0.21, frequency: second, duty: 0.5, hold: 0.05, release: 0.08, gain: 0.12),
            ],
            level: -19
        )
    }

    private static func select(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        SoundSynth.Design(
            layers: [
                Noise(clock: 20000, short: true, hold: 0.004, release: 0.006, gain: 0.3),
                Pulse(frequency: note(6, Int.random(in: 0...4, using: &random)), duty: 0.25, hold: 0.025, release: 0.02, gain: 0.5),
            ],
            level: -22
        )
    }

    private static func powerUp(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let base = Int.random(in: 0...2, using: &random)
        var layers: [any SoundLayer] = []
        var time = 0.0
        for step in 0..<8 {
            let pitch = note(4, base + step)
            let last = step == 7
            layers.append(Pulse(at: time, frequency: pitch, duty: step % 2 == 0 ? 0.5 : 0.25, hold: last ? 0.16 : 0.032, release: last ? 0.14 : 0.006, gain: 0.4 + 0.02 * Double(step)))
            time += 0.038
        }
        layers.append(Pulse(at: time + 0.05, frequency: note(4, base + 7), duty: 0.25, hold: 0.08, release: 0.1, gain: 0.12))
        return SoundSynth.Design(layers: layers, level: -19)
    }

    private static func dig(_ random: inout SoundSynth.Random) -> SoundSynth.Design {
        let delay = random.between(0...0.005)
        return SoundSynth.Design(
            layers: [
                Noise(at: delay, clock: random.between(6000...12000), hold: 0.012, release: 0.02, gain: 0.45),
                Pulse(at: delay, frequency: random.between(120...170), target: 90, slide: 0.03, duty: 0.25, hold: 0.015, release: 0.015, gain: 0.35),
            ],
            level: -25,
            floor: 80
        )
    }
}

private struct Pulse: SoundLayer {
    var at = 0.0
    var frequency: Double
    var target: Double?
    var slide = 0.0
    var duty: Double
    var hold: Double
    var release: Double
    var gain: Double
    var vibrato = 0.0
    var vibratoRate = 0.0

    var end: Double {
        at + hold + release
    }

    func add(into mix: UnsafeMutableBufferPointer<Double>, rate: Double, random: inout SoundSynth.Random) {
        let first = Int(at * rate)
        let count = min(Int((hold + release) * rate), mix.count - first)
        guard count > 0 else {
            return
        }
        var phase = 0.0
        for offset in 0..<count {
            let time = Double(offset) / rate
            var pitch = frequency
            if let target, slide > 0 {
                pitch = frequency * pow(target / frequency, min(time / slide, 1))
            }
            if vibrato > 0 {
                pitch *= 1 + vibrato * sin(2 * .pi * vibratoRate * time)
            }
            let step = pitch / rate
            var value = phase < duty ? 1.0 : -1.0
            value += Self.blep(phase, step)
            value -= Self.blep((phase + 1 - duty).truncatingRemainder(dividingBy: 1), step)
            mix[first + offset] += value * Self.envelope(time, hold: hold, release: release) * gain
            phase += step
            if phase >= 1 {
                phase -= 1
            }
        }
    }

    static func envelope(_ time: Double, hold: Double, release: Double) -> Double {
        let level = time < 0.0015 ? time / 0.0015 : (time < hold ? 1 : max(1 - (time - hold) / max(release, 1e-4), 0))
        return (level * 15).rounded(.up) / 15
    }

    private static func blep(_ phase: Double, _ step: Double) -> Double {
        if phase < step {
            let t = phase / step
            return t + t - t * t - 1
        }
        if phase > 1 - step {
            let t = (phase - 1) / step
            return t * t + t + t + 1
        }
        return 0
    }
}

private struct Noise: SoundLayer {
    var at = 0.0
    var clock: Double
    var short = false
    var hold: Double
    var release: Double
    var gain: Double

    var end: Double {
        at + hold + release
    }

    func add(into mix: UnsafeMutableBufferPointer<Double>, rate: Double, random: inout SoundSynth.Random) {
        let first = Int(at * rate)
        let count = min(Int((hold + release) * rate), mix.count - first)
        guard count > 0 else {
            return
        }
        var register: UInt16 = 1
        var counter = 0.0
        var bit = 1.0
        let tap: UInt16 = short ? 6 : 1
        for offset in 0..<count {
            counter += clock / rate
            while counter >= 1 {
                counter -= 1
                let feedback = (register & 1) ^ ((register >> tap) & 1)
                register = (register >> 1) | (feedback << 14)
                bit = register & 1 == 0 ? 1 : -1
            }
            let time = Double(offset) / rate
            mix[first + offset] += bit * Pulse.envelope(time, hold: hold, release: release) * gain
        }
    }
}
