import Foundation

struct GribField {
    struct Identity: Equatable {
        let category: Int
        let number: Int
    }

    enum Failure: Error {
        case malformed
        case unsupported
        case mismatched
    }

    static let pointLimit = 1 << 22

    let width: Int
    let height: Int
    let firstLatitude: Double
    let firstLongitude: Double
    let latitudeStep: Double
    let longitudeStep: Double
    let values: [Float]

    init(data: Data, identity: Identity, forecastHours: Int) throws {
        let bytes = [UInt8](data)
        let reader = GribReader(bytes: bytes)
        guard
            bytes.count >= 20,
            bytes[0] == 0x47, bytes[1] == 0x52, bytes[2] == 0x49, bytes[3] == 0x42,
            bytes[7] == 2
        else { throw Failure.malformed }
        guard bytes[6] == 0 else { throw Failure.mismatched }
        let total = try reader.unsigned(at: 8, count: 8)
        guard total == bytes.count, bytes[total - 4] == 0x37, bytes[total - 3] == 0x37, bytes[total - 2] == 0x37, bytes[total - 1] == 0x37 else {
            throw Failure.malformed
        }

        var sections: [Int: Range<Int>] = [:]
        var position = 16
        while position < total - 4 {
            let length = try reader.unsigned(at: position, count: 4)
            guard length >= 5, position + length <= total - 4 else { throw Failure.malformed }
            let number = Int(bytes[position + 4])
            guard (1...7).contains(number), sections[number] == nil else { throw Failure.unsupported }
            sections[number] = position..<(position + length)
            position += length
        }
        guard position == total - 4, let grid = sections[3], let product = sections[4], let packing = sections[5], let bitmap = sections[6], let payload = sections[7] else {
            throw Failure.malformed
        }

        guard grid.count >= 72, try reader.unsigned(at: grid.lowerBound + 12, count: 2) == 0, bytes[grid.lowerBound + 5] == 0 else {
            throw Failure.unsupported
        }
        let points = try reader.unsigned(at: grid.lowerBound + 6, count: 4)
        width = try reader.unsigned(at: grid.lowerBound + 30, count: 4)
        height = try reader.unsigned(at: grid.lowerBound + 34, count: 4)
        guard points <= Self.pointLimit, width > 1, height > 1, width * height == points, try reader.unsigned(at: grid.lowerBound + 38, count: 4) == 0 else {
            throw Failure.unsupported
        }
        firstLatitude = Double(try reader.signed(at: grid.lowerBound + 46, count: 4)) / 1e6
        firstLongitude = Double(try reader.signed(at: grid.lowerBound + 50, count: 4)) / 1e6
        longitudeStep = Double(try reader.unsigned(at: grid.lowerBound + 63, count: 4)) / 1e6
        latitudeStep = Double(try reader.unsigned(at: grid.lowerBound + 67, count: 4)) / 1e6
        guard bytes[grid.lowerBound + 71] == 0 else { throw Failure.unsupported }

        guard product.count >= 22, try reader.unsigned(at: product.lowerBound + 7, count: 2) == 0 else { throw Failure.mismatched }
        let category = Int(bytes[product.lowerBound + 9])
        let number = Int(bytes[product.lowerBound + 10])
        guard Identity(category: category, number: number) == identity else { throw Failure.mismatched }
        guard bytes[product.lowerBound + 17] == 1, try reader.unsigned(at: product.lowerBound + 18, count: 4) == forecastHours else {
            throw Failure.mismatched
        }

        guard bitmap.count >= 6, bytes[bitmap.lowerBound + 5] == 255 else { throw Failure.unsupported }

        guard packing.count >= 49, try reader.unsigned(at: packing.lowerBound + 9, count: 2) == 3 else { throw Failure.unsupported }
        guard try reader.unsigned(at: packing.lowerBound + 5, count: 4) == points else { throw Failure.malformed }
        let base = packing.lowerBound
        let reference = Double(Float(bitPattern: UInt32(try reader.unsigned(at: base + 11, count: 4))))
        let binaryScale = try reader.signed(at: base + 15, count: 2)
        let decimalScale = try reader.signed(at: base + 17, count: 2)
        let bits = Int(bytes[base + 19])
        guard bytes[base + 21] == 1, bytes[base + 22] == 0 else { throw Failure.unsupported }
        let groups = try reader.unsigned(at: base + 31, count: 4)
        let widthReference = Int(bytes[base + 35])
        let widthBits = Int(bytes[base + 36])
        let lengthReference = try reader.unsigned(at: base + 37, count: 4)
        let lengthIncrement = Int(bytes[base + 41])
        let lastLength = try reader.unsigned(at: base + 42, count: 4)
        let lengthBits = Int(bytes[base + 46])
        let order = Int(bytes[base + 47])
        let extra = Int(bytes[base + 48])
        guard
            reference.isFinite,
            (0...32).contains(bits), (0...32).contains(widthBits), (0...32).contains(lengthBits),
            (1...points).contains(groups),
            order == 1 || order == 2,
            (1...4).contains(extra)
        else { throw Failure.unsupported }

        var stream = GribBits(bytes: bytes, range: (payload.lowerBound + 5)..<payload.upperBound)
        var seeds: [Int] = []
        for _ in 0..<order {
            seeds.append(try stream.signed(bytes: extra))
        }
        let minimum = try stream.signed(bytes: extra)
        var references = [Int](repeating: 0, count: groups)
        for group in 0..<groups {
            references[group] = try stream.read(bits)
        }
        stream.align()
        var widths = [Int](repeating: 0, count: groups)
        for group in 0..<groups {
            widths[group] = try widthReference + stream.read(widthBits)
            guard widths[group] <= 32 else { throw Failure.malformed }
        }
        stream.align()
        var lengths = [Int](repeating: 0, count: groups)
        for group in 0..<groups {
            lengths[group] = try lengthReference + lengthIncrement * stream.read(lengthBits)
        }
        stream.align()
        lengths[groups - 1] = lastLength
        guard lengths.reduce(0, +) == points else { throw Failure.malformed }

        var packed = [Int](repeating: 0, count: points)
        var index = 0
        for group in 0..<groups {
            let groupWidth = widths[group]
            let groupReference = references[group]
            for _ in 0..<lengths[group] {
                packed[index] = try groupReference + stream.read(groupWidth) + minimum
                index += 1
            }
        }
        guard points > order else { throw Failure.malformed }
        if order == 1 {
            packed[0] = seeds[0]
            for index in 1..<points {
                packed[index] += packed[index - 1]
            }
        } else {
            packed[0] = seeds[0]
            packed[1] = seeds[1]
            for index in 2..<points {
                packed[index] += 2 * packed[index - 1] - packed[index - 2]
            }
        }

        let scale = pow(2.0, Double(binaryScale))
        let divisor = pow(10.0, Double(decimalScale))
        var values = [Float](repeating: 0, count: points)
        for index in 0..<points {
            let value = (reference + Double(packed[index]) * scale) / divisor
            guard value.isFinite else { throw Failure.malformed }
            values[index] = Float(value)
        }
        self.values = values
    }
}

private struct GribReader {
    let bytes: [UInt8]

    func unsigned(at offset: Int, count: Int) throws -> Int {
        guard offset >= 0, offset + count <= bytes.count else { throw GribField.Failure.malformed }
        var value = 0
        for index in offset..<(offset + count) {
            value = value << 8 | Int(bytes[index])
        }
        return value
    }

    func signed(at offset: Int, count: Int) throws -> Int {
        let raw = try unsigned(at: offset, count: count)
        let sign = 1 << (count * 8 - 1)
        return raw & sign == 0 ? raw : -(raw & (sign - 1))
    }
}

private struct GribBits {
    let bytes: [UInt8]
    let range: Range<Int>
    private var bit: Int

    init(bytes: [UInt8], range: Range<Int>) {
        self.bytes = bytes
        self.range = range
        bit = range.lowerBound * 8
    }

    mutating func read(_ count: Int) throws -> Int {
        guard count > 0 else { return 0 }
        guard bit + count <= range.upperBound * 8 else { throw GribField.Failure.malformed }
        var value = 0
        var remaining = count
        while remaining > 0 {
            let byte = Int(bytes[bit >> 3])
            let used = bit & 7
            let available = 8 - used
            let take = min(available, remaining)
            let chunk = (byte >> (available - take)) & ((1 << take) - 1)
            value = value << take | chunk
            remaining -= take
            bit += take
        }
        return value
    }

    mutating func signed(bytes count: Int) throws -> Int {
        let raw = try read(count * 8)
        let sign = 1 << (count * 8 - 1)
        return raw & sign == 0 ? raw : -(raw & (sign - 1))
    }

    mutating func align() {
        bit = (bit + 7) & ~7
    }
}
