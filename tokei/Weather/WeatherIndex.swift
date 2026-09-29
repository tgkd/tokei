import Foundation

struct WeatherIndex {
    struct Entry: Equatable {
        let offset: Int
        let parameter: String
        let level: String
        let time: String
    }

    let entries: [Entry]
    private let offsets: [Int]

    init?(text: String) {
        var entries: [Entry] = []
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: ":", omittingEmptySubsequences: false)
            guard fields.count >= 6, let offset = Int(fields[1]), offset >= 0 else { continue }
            entries.append(Entry(offset: offset, parameter: String(fields[3]), level: String(fields[4]), time: String(fields[5])))
        }
        guard !entries.isEmpty else { return nil }
        self.entries = entries
        offsets = Array(Set(entries.map(\.offset))).sorted()
    }

    func range(of field: WeatherField, key: WeatherKey) -> ClosedRange<Int>? {
        let matches = entries.filter { field.matches($0, key: key) }
        guard matches.count == 1, let start = matches.first?.offset else { return nil }
        guard let end = offsets.first(where: { $0 > start }) else { return nil }
        return start...(end - 1)
    }
}
