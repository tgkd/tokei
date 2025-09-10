import AppIntents
import WidgetKit
import Foundation

struct CycleTimeZoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Cycle Time Zone"
    static var description = IntentDescription("Cycles to the next time zone in the widget.")
    
    func perform() async throws -> some IntentResult {
        var currentTimeZones = loadSavedTimeZones()
        if currentTimeZones.isEmpty {
            currentTimeZones = Array(TimeZoneInfo.defaultTimeZones.prefix(3))
        }
        
        let rotatedTimeZones = Array(currentTimeZones.dropFirst() + currentTimeZones.prefix(1))
        saveTimeZones(rotatedTimeZones)
        
        WidgetCenter.shared.reloadTimelines(ofKind: "TokeiWidget")
        
        return .result()
    }
    
    private func loadSavedTimeZones() -> [TimeZoneInfo] {
        guard let data = UserDefaults.shared.data(forKey: "saved_timezones"),
              let timeZones = try? JSONDecoder().decode([TimeZoneInfo].self, from: data) else {
            return Array(TimeZoneInfo.defaultTimeZones.prefix(3))
        }
        return timeZones
    }
    
    private func saveTimeZones(_ timeZones: [TimeZoneInfo]) {
        if let data = try? JSONEncoder().encode(timeZones) {
            UserDefaults.shared.set(data, forKey: "saved_timezones")
        }
    }
}

struct RefreshTimeZonesIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Time Zones"
    static var description = IntentDescription("Refreshes all time zone data in the widget.")
    
    func perform() async throws -> some IntentResult {
        WidgetCenter.shared.reloadTimelines(ofKind: "TokeiWidget")
        return .result()
    }
}

struct RemoveTimeZoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Remove Time Zone"
    static var description = IntentDescription("Removes a time zone from the widget.")
    
    @Parameter(title: "Time Zone ID")
    var timeZoneID: String
    
    func perform() async throws -> some IntentResult {
        var currentTimeZones = loadSavedTimeZones()
        currentTimeZones.removeAll { $0.timeZoneIdentifier == timeZoneID }
        
        if currentTimeZones.isEmpty {
            currentTimeZones = Array(TimeZoneInfo.defaultTimeZones.prefix(3))
        }
        
        saveTimeZones(currentTimeZones)
        WidgetCenter.shared.reloadTimelines(ofKind: "TokeiWidget")
        
        return .result()
    }
    
    private func loadSavedTimeZones() -> [TimeZoneInfo] {
        guard let data = UserDefaults.shared.data(forKey: "saved_timezones"),
              let timeZones = try? JSONDecoder().decode([TimeZoneInfo].self, from: data) else {
            return Array(TimeZoneInfo.defaultTimeZones.prefix(3))
        }
        return timeZones
    }
    
    private func saveTimeZones(_ timeZones: [TimeZoneInfo]) {
        if let data = try? JSONEncoder().encode(timeZones) {
            UserDefaults.shared.set(data, forKey: "saved_timezones")
        }
    }
}

struct AddTimeZoneIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Time Zone"
    static var description = IntentDescription("Adds a new time zone to the widget.")
    
    @Parameter(title: "City Name")
    var cityName: String
    
    @Parameter(title: "Time Zone Identifier") 
    var timeZoneIdentifier: String
    
    @Parameter(title: "Weather Emoji")
    var weatherEmoji: String
    
    func perform() async throws -> some IntentResult {
        var currentTimeZones = loadSavedTimeZones()
        
        let newTimeZone = TimeZoneInfo(
            cityName: cityName,
            timeZoneIdentifier: timeZoneIdentifier,
            weatherEmoji: weatherEmoji.isEmpty ? "🌍" : weatherEmoji
        )
        
        currentTimeZones.append(newTimeZone)
        saveTimeZones(Array(currentTimeZones.prefix(6)))
        
        WidgetCenter.shared.reloadTimelines(ofKind: "TokeiWidget")
        
        return .result()
    }
    
    private func loadSavedTimeZones() -> [TimeZoneInfo] {
        guard let data = UserDefaults.shared.data(forKey: "saved_timezones"),
              let timeZones = try? JSONDecoder().decode([TimeZoneInfo].self, from: data) else {
            return Array(TimeZoneInfo.defaultTimeZones.prefix(3))
        }
        return timeZones
    }
    
    private func saveTimeZones(_ timeZones: [TimeZoneInfo]) {
        if let data = try? JSONEncoder().encode(timeZones) {
            UserDefaults.shared.set(data, forKey: "saved_timezones")
        }
    }
}

struct AdjustTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Adjust Time"
    static var description = IntentDescription("Adjusts the displayed time by a specified number of minutes.")
    
    @Parameter(title: "Minutes to Add")
    var minutesToAdd: Int
    
    func perform() async throws -> some IntentResult {
        let currentOffset = UserDefaults.shared.integer(forKey: "time_offset_minutes")
        let newOffset = currentOffset + minutesToAdd
        UserDefaults.shared.set(newOffset, forKey: "time_offset_minutes")
        
        WidgetCenter.shared.reloadTimelines(ofKind: "TokeiWidget")
        
        return .result()
    }
}

struct ResetTimeIntent: AppIntent {
    static var title: LocalizedStringResource = "Reset Time"
    static var description = IntentDescription("Resets the time offset to current time.")
    
    func perform() async throws -> some IntentResult {
        UserDefaults.shared.set(0, forKey: "time_offset_minutes")
        
        WidgetCenter.shared.reloadTimelines(ofKind: "TokeiWidget")
        
        return .result()
    }
}