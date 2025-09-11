import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TokeiEntry {
        TokeiEntry(
            date: Date(),
            timeZones: Array(TimeZoneInfo.defaultTimeZones.prefix(3)),
            selectedTimeZones: [],
            currentTimeOffsetMinutes: 0
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> TokeiEntry {
        TokeiEntry(
            date: Date(),
            timeZones: Array(TimeZoneInfo.defaultTimeZones.prefix(3)),
            selectedTimeZones: [],
            currentTimeOffsetMinutes: UserDefaults.shared.integer(forKey: "time_offset_minutes")
        )
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<TokeiEntry> {
        var entries: [TokeiEntry] = []
        
        let currentDate = Date()
        let savedTimeZones = loadSavedTimeZones()
        let displayTimeZones = savedTimeZones.isEmpty ? Array(TimeZoneInfo.defaultTimeZones.prefix(3)) : savedTimeZones
        let currentTimeOffset = UserDefaults.shared.integer(forKey: "time_offset_minutes")
        
        for i in 0..<60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: i, to: currentDate)!
            let entry = TokeiEntry(
                date: entryDate,
                timeZones: displayTimeZones,
                selectedTimeZones: savedTimeZones,
                currentTimeOffsetMinutes: currentTimeOffset
            )
            entries.append(entry)
        }
        
        return Timeline(entries: entries, policy: .atEnd)
    }
    
    private func loadSavedTimeZones() -> [TimeZoneInfo] {
        guard let data = UserDefaults.shared.data(forKey: "saved_timezones"),
              let timeZones = try? JSONDecoder().decode([TimeZoneInfo].self, from: data) else {
            return Array(TimeZoneInfo.defaultTimeZones.prefix(3))
        }
        return Array(timeZones.prefix(4))
    }
}

struct TokeiEntry: TimelineEntry {
    let date: Date
    let timeZones: [TimeZoneInfo]
    let selectedTimeZones: [TimeZoneInfo]
    let currentTimeOffsetMinutes: Int
    
    var formattedTimeOffset: String {
        if currentTimeOffsetMinutes == 0 {
            return "Now"
        }
        let hours = abs(currentTimeOffsetMinutes) / 60
        let minutes = abs(currentTimeOffsetMinutes) % 60
        let sign = currentTimeOffsetMinutes >= 0 ? "+" : "-"
        
        if minutes == 0 {
            return String(format: "%@%dh", sign, hours)
        } else {
            return String(format: "%@%d:%02d", sign, hours, minutes)
        }
    }
}

extension UserDefaults {
    static let shared = UserDefaults(suiteName: "group.tokei.widget")!
}