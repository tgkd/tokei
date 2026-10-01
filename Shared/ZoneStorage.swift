import Foundation

enum ZoneStorage {
    static let suiteName = "group.tokei.widget"
    static let zonesKey = "saved_timezones"
    static let shiftKey = "time_offset_minutes"
    static let homeZoneKey = "home_timezone"
    static let widgetLookKey = "widget_look"

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

    static func loadWidgetLook() -> WidgetLook {
        guard let data = defaults.data(forKey: widgetLookKey) else { return .standard }
        guard let look = try? JSONDecoder().decode(WidgetLook.self, from: data) else { return .standard }
        return look
    }

    static func saveWidgetLook(_ look: WidgetLook) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(look), data != defaults.data(forKey: widgetLookKey) else { return false }
        defaults.set(data, forKey: widgetLookKey)
        return true
    }
}
