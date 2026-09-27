import Foundation

enum ZoneStorage {
    static let suiteName = "group.tokei.widget"
    static let zonesKey = "saved_timezones"
    static let shiftKey = "time_offset_minutes"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func loadZones() -> [Zone] {
        guard let data = defaults.data(forKey: zonesKey) else { return Zone.defaults }
        guard let zones = try? JSONDecoder().decode([Zone].self, from: data) else { return Zone.defaults }
        return zones
    }

    static func saveZones(_ zones: [Zone]) {
        guard let data = try? JSONEncoder().encode(zones) else { return }
        defaults.set(data, forKey: zonesKey)
    }

    static func loadShift() -> Int {
        defaults.integer(forKey: shiftKey)
    }

    static func saveShift(_ minutes: Int) {
        defaults.set(minutes, forKey: shiftKey)
    }
}
