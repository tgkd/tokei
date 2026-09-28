import Foundation

protocol SoundLayer {
    var end: Double { get }
    func add(into mix: UnsafeMutableBufferPointer<Double>, rate: Double, random: inout SoundSynth.Random)
}

extension SoundSynth {
    struct Random: RandomNumberGenerator {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed
        }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }

        mutating func unit() -> Double {
            Double(next() >> 11) * 0x1p-53
        }

        mutating func signed() -> Double {
            unit() * 2 - 1
        }

        mutating func between(_ range: ClosedRange<Double>) -> Double {
            range.lowerBound + (range.upperBound - range.lowerBound) * unit()
        }

        mutating func scaled(_ range: ClosedRange<Double>) -> Double {
            range.lowerBound * pow(range.upperBound / range.lowerBound, unit())
        }

        mutating func chance(_ probability: Double) -> Bool {
            unit() < probability
        }

        mutating func sign() -> Double {
            chance(0.5) ? 1 : -1
        }
    }

    struct Biquad {
        private var b0: Double
        private var b1: Double
        private var b2: Double
        private var a1: Double
        private var a2: Double
        private var z1 = 0.0
        private var z2 = 0.0

        static func bandPass(frequency: Double, resonance: Double, rate: Double) -> Biquad {
            let omega = 2 * Double.pi * min(frequency, rate * 0.45) / rate
            let alpha = sin(omega) / (2 * resonance)
            let norm = 1 + alpha
            return Biquad(b0: alpha / norm, b1: 0, b2: -alpha / norm, a1: -2 * cos(omega) / norm, a2: (1 - alpha) / norm)
        }

        static func highPass(frequency: Double, resonance: Double, rate: Double) -> Biquad {
            let omega = 2 * Double.pi * min(frequency, rate * 0.45) / rate
            let alpha = sin(omega) / (2 * resonance)
            let cosine = cos(omega)
            let norm = 1 + alpha
            return Biquad(b0: (1 + cosine) / 2 / norm, b1: -(1 + cosine) / norm, b2: (1 + cosine) / 2 / norm, a1: -2 * cosine / norm, a2: (1 - alpha) / norm)
        }

        mutating func retune(_ other: Biquad) {
            b0 = other.b0
            b1 = other.b1
            b2 = other.b2
            a1 = other.a1
            a2 = other.a2
        }

        mutating func process(_ input: Double) -> Double {
            let output = b0 * input + z1
            z1 = b1 * input - a1 * output + z2
            z2 = b2 * input - a2 * output
            return output
        }
    }

    static func bandGain(frequency: Double, resonance: Double, rate: Double) -> Double {
        (3 * resonance * rate / (Double.pi * min(frequency, rate * 0.45))).squareRoot()
    }

    struct Tone: SoundLayer {
        var voice: Voice
        var at = 0.0

        var end: Double {
            at + voice.duration
        }

        func add(into mix: UnsafeMutableBufferPointer<Double>, rate: Double, random: inout Random) {
            let first = Int(at * rate)
            for (offset, sample) in waveform(voice, rate: rate, random: &random).enumerated() {
                let index = first + offset
                guard index < mix.count else { return }
                mix[index] += sample
            }
        }
    }

    struct Wash: SoundLayer {
        var at = 0.0
        var attack: Double
        var decay: Double
        var frequency: Double
        var sweep = 1.0
        var resonance: Double
        var gain: Double

        var end: Double {
            at + attack + decay * 6
        }

        func add(into mix: UnsafeMutableBufferPointer<Double>, rate: Double, random: inout Random) {
            let first = Int(at * rate)
            let rise = max(Int(attack * rate), 1)
            let count = min(rise + Int(decay * 6 * rate), mix.count - first)
            guard count > 0 else { return }
            var filter = Biquad.bandPass(frequency: frequency, resonance: resonance, rate: rate)
            var level = gain * bandGain(frequency: frequency, resonance: resonance, rate: rate)
            let fade = exp(-1 / (decay * rate))
            var envelope = 1.0
            for offset in 0..<count {
                if sweep != 1, offset % 32 == 0 {
                    let tuned = frequency * pow(sweep, Double(offset) / Double(count))
                    filter.retune(.bandPass(frequency: tuned, resonance: resonance, rate: rate))
                    level = gain * bandGain(frequency: tuned, resonance: resonance, rate: rate)
                }
                if offset < rise {
                    let phase = sin(Double.pi / 2 * Double(offset + 1) / Double(rise))
                    envelope = phase * phase
                } else {
                    envelope *= fade
                }
                mix[first + offset] += level * envelope * filter.process(random.signed())
            }
        }
    }

    struct Grains: SoundLayer {
        var at = 0.0
        var rise: Double
        var fall: Double
        var density: Double
        var band: ClosedRange<Double>
        var cycles: ClosedRange<Double>
        var resonance: Double
        var grit: Double
        var gain: Double

        var end: Double {
            at + rise + fall * 5 + cycles.upperBound / band.lowerBound + 0.005
        }

        func add(into mix: UnsafeMutableBufferPointer<Double>, rate: Double, random: inout Random) {
            let span = rise + fall * 5
            var time = 0.0
            while true {
                time -= log(1 - random.unit()) / density
                guard time < span else { return }
                let weight = time < rise ? pow(sin(Double.pi / 2 * time / rise), 2) : exp(-(time - rise) / fall)
                guard random.unit() < weight else { continue }
                let frequency = random.scaled(band)
                let amplitude = gain * weight.squareRoot() * pow(random.unit(), grit) * random.sign()
                burst(
                    into: mix,
                    first: Int((at + time) * rate),
                    count: max(Int(random.between(cycles) / frequency * rate), 1),
                    frequency: frequency,
                    amplitude: amplitude,
                    rate: rate,
                    random: &random
                )
            }
        }

        private func burst(into mix: UnsafeMutableBufferPointer<Double>, first: Int, count: Int, frequency: Double, amplitude: Double, rate: Double, random: inout Random) {
            var filter = Biquad.bandPass(frequency: frequency, resonance: resonance, rate: rate)
            let total = min(count + Int(4 * resonance / (Double.pi * frequency) * rate), mix.count - first)
            guard total > 0 else { return }
            let fade = exp(-4 / Double(count))
            var level = amplitude * bandGain(frequency: frequency, resonance: resonance, rate: rate)
            for offset in 0..<total {
                let input = offset < count ? level * random.signed() : 0
                level *= fade
                mix[first + offset] += filter.process(input)
            }
        }
    }

    struct Ring: SoundLayer {
        struct Partial {
            var frequency: Double
            var decay: Double
            var gain: Double
            var beat = 0.0
        }

        var at = 0.0
        var partials: [Partial]

        var end: Double {
            at + (partials.map(\.decay).max() ?? 0) * 6
        }

        func add(into mix: UnsafeMutableBufferPointer<Double>, rate: Double, random: inout Random) {
            let first = Int(at * rate)
            for partial in partials where partial.frequency < rate * 0.45 {
                if partial.beat == 0 {
                    sing(partial.frequency, decay: partial.decay, gain: partial.gain, first: first, into: mix, rate: rate)
                } else {
                    sing(partial.frequency - partial.beat / 2, decay: partial.decay, gain: partial.gain * 0.6, first: first, into: mix, rate: rate)
                    sing(partial.frequency + partial.beat / 2, decay: partial.decay, gain: partial.gain * 0.4, first: first, into: mix, rate: rate)
                }
            }
        }

        private func sing(_ frequency: Double, decay: Double, gain: Double, first: Int, into mix: UnsafeMutableBufferPointer<Double>, rate: Double) {
            let omega = 2 * Double.pi * frequency / rate
            let damping = exp(-1 / (decay * rate))
            let coefficient = 2 * damping * cos(omega)
            let square = damping * damping
            let count = min(Int(decay * 6 * rate), mix.count - first)
            var previous = 0.0
            var current = gain * damping * sin(omega)
            var offset = 1
            while offset < count {
                mix[first + offset] += current
                let next = coefficient * current - square * previous
                previous = current
                current = next
                offset += 1
            }
        }
    }
}
