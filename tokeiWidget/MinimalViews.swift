import SwiftUI
import WidgetKit

struct MinimalZoneView: View {
    @Environment(\.widgetLook) private var look

    let zone: Zone
    let entry: ClockEntry
    var timeSize: CGFloat = 40

    var body: some View {
        let date = entry.displayDate
        VStack(alignment: .leading, spacing: 2) {
            Text(zone.cityName)
                .font(look.typography.title.font(size: 13))
                .foregroundStyle(look.secondaryInk)
                .lineLimit(1)
            Text(ZoneClock.time(date, in: zone.timeZone))
                .font(look.typography.digits.font(size: timeSize))
                .monospacedDigit()
                .foregroundStyle(entry.isShifted ? look.accent : look.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .widgetAccentable()
            Text(ZoneClock.weekdayAndDate(date, in: zone.timeZone))
                .caption(look, size: 12)
                .textCase(look.typography.uppercasedCaptions ? .uppercase : nil)
                .foregroundStyle(look.faintInk)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
    }
}

struct MinimalSmallView: View {
    @Environment(\.widgetLook) private var look

    let entry: ClockEntry

    var body: some View {
        let zone = entry.zones.first ?? Zone.home(for: entry.homeZone)
        MinimalZoneView(zone: zone, entry: entry)
            .overlay(alignment: .topTrailing) {
                if entry.isShifted {
                    Text(ZoneClock.shiftLabel(minutes: entry.shiftMinutes))
                        .font(look.typography.title.font(size: 10))
                        .foregroundStyle(look.accent)
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
