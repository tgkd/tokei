import SwiftUI
import WidgetKit

struct AccessoryRectangularView: View {
    let entry: ClockEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(entry.zones.prefix(3)) { zone in
                HStack {
                    Text(zone.cityName)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text(ZoneClock.time(entry.displayDate, in: zone.timeZone))
                        .monospacedDigit()
                        .widgetAccentable()
                }
                .font(.system(size: 13, weight: .semibold))
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
    let entry: ClockEntry

    var body: some View {
        let zone = entry.zones.first ?? Zone.home(for: entry.homeZone)
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Text(ZoneClock.time(entry.displayDate, in: zone.timeZone))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .widgetAccentable()
                Text(String(zone.cityName.prefix(3)).uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(4)
        }
    }
}
