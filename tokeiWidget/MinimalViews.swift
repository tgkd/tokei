import SwiftUI
import WidgetKit

struct MinimalZoneView: View {
    let zone: Zone
    let entry: ClockEntry
    var timeSize: CGFloat = 40

    var body: some View {
        let date = entry.displayDate
        VStack(alignment: .leading, spacing: 2) {
            Text(zone.cityName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
            Text(ZoneClock.time(date, in: zone.timeZone))
                .font(.system(size: timeSize, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(entry.isShifted ? Color.sunlight : Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .widgetAccentable()
            Text(ZoneClock.weekdayAndDate(date, in: zone.timeZone))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
}

struct MinimalSmallView: View {
    let entry: ClockEntry

    var body: some View {
        let zone = entry.zones.first ?? Zone.local
        MinimalZoneView(zone: zone, entry: entry)
            .overlay(alignment: .topTrailing) {
                if entry.isShifted {
                    Text(ZoneClock.shiftLabel(minutes: entry.shiftMinutes))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.sunlight)
                }
            }
    }
}

struct MinimalMediumView: View {
    let entry: ClockEntry

    var body: some View {
        HStack(spacing: 16) {
            ForEach(entry.zones.prefix(2)) { zone in
                MinimalZoneView(zone: zone, entry: entry, timeSize: 38)
            }
        }
    }
}
