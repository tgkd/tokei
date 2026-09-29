import Foundation

struct WeatherBundle: Codable, Sendable {
    let key: WeatherKey
    let records: [WeatherField: Data]

    var byteCount: Int {
        records.values.reduce(0) { $0 + $1.count }
    }
}

struct WeatherCache: Sendable {
    static let limit = 16

    private let directory: URL?

    init() {
        directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("Weather", isDirectory: true)
    }

    func bundle(for key: WeatherKey) -> WeatherBundle? {
        guard let url = url(for: key), let data = try? Data(contentsOf: url) else { return nil }
        return try? PropertyListDecoder().decode(WeatherBundle.self, from: data)
    }

    func keys() -> [WeatherKey] {
        guard let directory, let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else { return [] }
        return names.compactMap { name -> WeatherKey? in
            let parts = name.replacingOccurrences(of: ".plist", with: "").split(separator: "-")
            guard parts.count == 2, let seconds = Int(parts[0]), let lead = Int(parts[1]) else { return nil }
            return WeatherKey(cycle: Date(timeIntervalSince1970: Double(seconds)), lead: lead)
        }
    }

    func store(_ bundle: WeatherBundle) {
        guard let directory, let url = url(for: bundle.key) else { return }
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        guard let data = try? encoder.encode(bundle) else { return }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
        prune()
    }

    private func prune() {
        let stale = keys().sorted { $0.cycle == $1.cycle ? $0.lead < $1.lead : $0.cycle > $1.cycle }.dropFirst(Self.limit)
        for key in stale {
            if let url = url(for: key) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    private func url(for key: WeatherKey) -> URL? {
        directory?.appendingPathComponent("\(key.cacheName).plist")
    }
}
