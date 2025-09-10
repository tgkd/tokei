import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TokeiEntry {
        TokeiEntry(
            date: Date(),
            timeZones: Array(TimeZoneInfo.defaultTimeZones.prefix(3)),
            selectedTimeZones: []
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> TokeiEntry {
        TokeiEntry(
            date: Date(),
            timeZones: Array(TimeZoneInfo.defaultTimeZones.prefix(3)),
            selectedTimeZones: []
        )
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<TokeiEntry> {
        var entries: [TokeiEntry] = []
        
        let currentDate = Date()
        let savedTimeZones = loadSavedTimeZones()
        let displayTimeZones = savedTimeZones.isEmpty ? Array(TimeZoneInfo.defaultTimeZones.prefix(3)) : savedTimeZones
        
        for i in 0..<60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: i, to: currentDate)!
            let entry = TokeiEntry(
                date: entryDate,
                timeZones: displayTimeZones,
                selectedTimeZones: savedTimeZones
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
}

extension UserDefaults {
    static let shared = UserDefaults(suiteName: "group.tokei.widget")!
}