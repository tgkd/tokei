import SwiftUI
import WidgetKit

struct AccessoryRectangularView: View {
    @Environment(\.widgetLook) private var look

    let entry: ClockEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(entry.zones.prefix(3)) { zone in
                HStack {
                    Text(zone.cityName)
                        .font(look.typography.title.font(size: 13))
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(ZoneClock.time(entry.displayDate, in: zone.timeZone))
                        .font(look.typography.digits.font(size: 13))
                        .monospacedDigit()
                        .widgetAccentable()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AccessoryInlineView: View {
    let entry: ClockEntry

    var body: some View {
        if let zone = entry.zones.first {
            Text("\(zone.cityName) \(ZoneClock.time(entry.displayDate, in: zone.timeZone))")
        } else {
            Text(ZoneClock.time(entry.displayDate, in: entry.homeZone))
        }
    }
}

struct AccessoryCircularView: View {
    @Environment(\.widgetLook) private var look

    let entry: ClockEntry

    var body: some View {
        let zone = entry.zones.first ?? Zone.home(for: entry.homeZone)
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(ZoneClock.time(entry.displayDate, in: zone.timeZone))
                    .font(look.typography.digits.font(size: 13))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
                Text(String(zone.cityName.prefix(3)).uppercased())
                    .font(look.typography.title.font(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(4)
        }
    }
}
