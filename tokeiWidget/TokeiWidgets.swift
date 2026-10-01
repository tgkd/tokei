import SwiftUI
import WidgetKit

@main
struct TokeiWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorldClockWidget()
        CompactClockWidget()
        MinimalClockWidget()
    }
}

struct WorldClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TokeiWidget", provider: ClockProvider(includesMap: true)) { entry in
            WorldClockEntryView(entry: entry)
        }
        .configurationDisplayName("World Clock")
        .description("Your cities on a live day and night map.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular, .accessoryInline, .accessoryCircular])
        .contentMarginsDisabled()
    }
}

struct CompactClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TokeiCompactWidget", provider: ClockProvider(includesMap: false)) { entry in
            CompactEntryView(entry: entry)
        }
        .configurationDisplayName("Compact World Clock")
        .description("Several cities at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct MinimalClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TokeiMinimalWidget", provider: ClockProvider(includesMap: false)) { entry in
            MinimalEntryView(entry: entry)
        }
        .configurationDisplayName("Minimal World Clock")
        .description("One or two cities, large.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WorldClockEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetContentMargins) private var margins

    let entry: ClockEntry

    var body: some View {
        content
            .themedContainer(entry.look)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .systemMedium:
            WorldClockMediumView(entry: entry)
        case .systemLarge:
            WorldClockLargeView(entry: entry)
        case .accessoryRectangular:
            AccessoryRectangularView(entry: entry)
        case .accessoryInline:
            AccessoryInlineView(entry: entry)
        case .accessoryCircular:
            AccessoryCircularView(entry: entry)
        default:
            WorldClockSmallView(entry: entry)
                .padding(margins)
        }
    }
}

struct CompactEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetContentMargins) private var margins

    let entry: ClockEntry

    var body: some View {
        Group {
            if family == .systemMedium {
                CompactMediumView(entry: entry)
            } else {
                CompactSmallView(entry: entry)
                    .padding(margins)
            }
        }
        .themedContainer(entry.look)
    }
}

struct MinimalEntryView: View {
    @Environment(\.widgetFamily) private var family

    let entry: ClockEntry

    var body: some View {
        Group {
            if family == .systemMedium {
                MinimalMediumView(entry: entry)
            } else {
                MinimalSmallView(entry: entry)
            }
        }
        .themedContainer(entry.look)
    }
}
