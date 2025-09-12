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

struct TokeiCompactWidget: Widget {
    let kind: String = "TokeiCompactWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            TokeiCompactWidgetEntryView(entry: entry)
                .containerBackground(Color(.systemBackground), for: .widget)
        }
        .configurationDisplayName("Compact World Clock")
        .description("A compact view of world time zones.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct TokeiMinimalWidget: Widget {
    let kind: String = "TokeiMinimalWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            TokeiMinimalWidgetEntryView(entry: entry)
                .containerBackground(Color(.systemBackground), for: .widget)
        }
        .configurationDisplayName("Minimal World Clock")
        .description("A minimal view showing essential time information.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}