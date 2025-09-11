import WidgetKit
import SwiftUI

struct TokeiWidget: Widget {
    let kind: String = "TokeiWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            TokeiWidgetEntryView(entry: entry)
                .containerBackground(Color(.systemBackground), for: .widget)
        }
        .configurationDisplayName("World Clock")
        .description("Keep track of time zones around the world.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemSmall) {
    TokeiWidget()
} timeline: {
    TokeiEntry(
        date: .now, 
        timeZones: Array(TimeZoneInfo.defaultTimeZones.prefix(1)),
        selectedTimeZones: [],
        currentTimeOffsetMinutes: 0
    )
    TokeiEntry(
        date: .now, 
        timeZones: Array(TimeZoneInfo.defaultTimeZones.prefix(1)),
        selectedTimeZones: [],
        currentTimeOffsetMinutes: 0
    )
}

#Preview(as: .systemMedium) {
    TokeiWidget()
} timeline: {
    TokeiEntry(
        date: .now,
        timeZones: Array(TimeZoneInfo.defaultTimeZones.prefix(2)),
        selectedTimeZones: [],
        currentTimeOffsetMinutes: 0
    )
}

#Preview(as: .systemLarge) {
    TokeiWidget()
} timeline: {
    TokeiEntry(
        date: .now,
        timeZones: Array(TimeZoneInfo.defaultTimeZones.prefix(4)),
        selectedTimeZones: [],
        currentTimeOffsetMinutes: 0
    )
}