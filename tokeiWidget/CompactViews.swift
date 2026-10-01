import SwiftUI
import WidgetKit

struct CompactSmallView: View {
    @Environment(\.widgetLook) private var look

    let entry: ClockEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(entry.zones.prefix(4)) { zone in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(zone.cityName)
                        .font(look.typography.caption.font(size: 12))
                        .foregroundStyle(look.secondaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .frame(minWidth: 44, alignment: .leading)
                    Spacer(minLength: 0)
                    Text(ZoneClock.time(entry.displayDate, in: zone.timeZone))
                        .font(look.typography.digits.font(size: 15))
                        .monospacedDigit()
                        .foregroundStyle(entry.isShifted ? look.accent : look.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .layoutPriority(1)
                        .widgetAccentable()
                }
                .frame(maxHeight: .infinity)
            }
            if entry.isShifted {
                Text(ZoneClock.shiftLabel(minutes: entry.shiftMinutes))
                    .font(look.typography.title.font(size: 10))
                    .foregroundStyle(look.accent)
            }
        }
    }
}

struct CompactMediumView: View {
    @Environment(\.widgetContentMargins) private var margins
    @Environment(\.widgetLook) private var look

    let entry: ClockEntry

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                ForEach(Array(entry.zones.prefix(4).enumerated()), id: \.element.id) { index, zone in
                    if index > 0 {
                        Rectangle()
                            .fill(look.rule)
                            .frame(width: 0.5)
                            .padding(.vertical, 10)
                    }
                    column(zone)
                        .invalidatableContent()
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(EdgeInsets(top: margins.top, leading: margins.leading, bottom: 0, trailing: margins.trailing))
            ShiftControls(shiftMinutes: entry.shiftMinutes, stepMinutes: 30)
                .padding(.bottom, 8)
        }
    }

    private func column(_ zone: Zone) -> some View {
        let date = entry.displayDate
        let offset = ZoneClock.offsetMinutes(of: zone.timeZone, from: entry.homeZone, at: date)
        let sun = SolarPosition(date: date)
        let daylight = zone.location.map { ZoneClock.daylight(at: $0, sun: sun) } ?? .day
        return VStack(spacing: 6) {
            Image(systemName: daylight.symbolName)
                .symbolRenderingMode(daylight == .night ? .hierarchical : .multicolor)
                .foregroundStyle(look.secondaryInk)
                .font(.system(size: 14, weight: look.typography.symbolWeight.fontWeight))
            Text(zone.cityName)
                .font(look.typography.title.font(size: 11))
                .foregroundStyle(look.secondaryInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(ZoneClock.time(date, in: zone.timeZone))
                .font(look.typography.digits.font(size: 20))
                .monospacedDigit()
                .foregroundStyle(entry.isShifted ? look.accent : look.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
            Text(ZoneClock.offsetLabel(minutes: offset))
                .caption(look, size: 10)
                .foregroundStyle(look.faintInk)
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
    }
}
