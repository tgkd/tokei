import Foundation

enum ZoneStorage {
    static let suiteName = "group.tokei.widget"
    static let zonesKey = "saved_timezones"
    static let shiftKey = "time_offset_minutes"
    static let homeZoneKey = "home_timezone"

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

    static func loadHomeZoneIdentifier() -> String? {
        guard let identifier = defaults.string(forKey: homeZoneKey), TimeZone(identifier: identifier) != nil else { return nil }
        return identifier
    }

    static func saveHomeZoneIdentifier(_ identifier: String?) {
        if let identifier {
            defaults.set(identifier, forKey: homeZoneKey)
        } else {
            defaults.removeObject(forKey: homeZoneKey)
        }
    }

    static func homeZone(for identifier: String?) -> TimeZone {
        identifier.flatMap { TimeZone(identifier: $0) } ?? .current
    }

    static func loadHomeZone() -> TimeZone {
        homeZone(for: loadHomeZoneIdentifier())
    }
}
