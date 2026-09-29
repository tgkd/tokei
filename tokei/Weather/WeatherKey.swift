import Foundation

struct WeatherKey: Hashable, Codable, Sendable {
    let cycle: Date
    let lead: Int

    var validDate: Date {
        cycle.addingTimeInterval(Double(lead) * 3600)
    }

    var timeLabel: String {
        lead == 0 ? "anl" : "\(lead) hour fcst"
    }

    func fileURL(on host: URL) -> URL {
        let parts = Calendar.utc.dateComponents([.year, .month, .day, .hour], from: cycle)
        let day = String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        let hour = String(format: "%02d", parts.hour ?? 0)
        let path = "gfs.\(day)/\(hour)/atmos/gfs.t\(hour)z.pgrb2.1p00.f\(String(format: "%03d", lead))"
        return host.appendingPathComponent(path)
    }

    var cacheName: String {
        "\(Int(cycle.timeIntervalSince1970))-\(lead)"
    }
}

enum WeatherSchedule {
    static let hosts = [
        URL(string: "https://noaa-gfs-bdp-pds.s3.amazonaws.com")!,
        URL(string: "https://storage.googleapis.com/global-forecast-system")!,
        URL(string: "https://noaagfs.blob.core.windows.net/gfs")!,
    ]
    static let step: TimeInterval = 3 * 3600
    static let cycleInterval: TimeInterval = 6 * 3600
    static let longestLead = 240
    static let fallbackCycles = 4

    static func validDate(near date: Date) -> Date {
        Date(timeIntervalSince1970: (date.timeIntervalSince1970 / step).rounded() * step)
    }

    static func publication(of key: WeatherKey) -> Date {
        key.cycle.addingTimeInterval(3.5 * 3600 + Double(key.lead) * 18)
    }

    static func candidates(for target: Date, now: Date) -> [WeatherKey] {
        var cycle = Date(timeIntervalSince1970: floor(min(target, now).timeIntervalSince1970 / cycleInterval) * cycleInterval)
        var keys: [WeatherKey] = []
        var probed = 0
        while keys.count < fallbackCycles && probed < fallbackCycles + 3 {
            let lead = Int((target.timeIntervalSince(cycle) / 3600).rounded())
            let key = WeatherKey(cycle: cycle, lead: lead)
            if lead >= 0 && lead <= longestLead && lead % 3 == 0 && publication(of: key) <= now {
                keys.append(key)
            }
            cycle = cycle.addingTimeInterval(-cycleInterval)
            probed += 1
        }
        return keys
    }

    static func refreshDate(after key: WeatherKey, target: Date, now: Date) -> Date? {
        if let best = candidates(for: target, now: now).first, best.cycle > key.cycle {
            return now.addingTimeInterval(10 * 60)
        }
        let next = key.cycle.addingTimeInterval(cycleInterval)
        guard next <= target else { return nil }
        let lead = Int((target.timeIntervalSince(next) / 3600).rounded())
        guard lead >= 0 else { return nil }
        return max(publication(of: WeatherKey(cycle: next, lead: lead)), now.addingTimeInterval(60))
    }
}

extension Calendar {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()
}
