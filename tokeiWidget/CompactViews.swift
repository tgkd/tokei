import SwiftUI
import WidgetKit

struct CompactSmallView: View {
    let entry: ClockEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(entry.zones.prefix(4)) { zone in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(zone.cityName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(ZoneClock.time(entry.displayDate, in: zone.timeZone))
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(entry.isShifted ? Color.sunlight : Color.white)
                        .fixedSize()
                        .layoutPriority(1)
                        .widgetAccentable()
                }
                .frame(maxHeight: .infinity)
            }
            if entry.isShifted {
                Text(ZoneClock.shiftLabel(minutes: entry.shiftMinutes))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.sunlight)
            }
        }
    }
}

struct CompactMediumView: View {
    let entry: ClockEntry

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(entry.zones.prefix(4).enumerated()), id: \.element.id) { index, zone in
                if index > 0 {
                    Rectangle()
                        .fill(.white.opacity(0.08))
                        .frame(width: 0.5)
                        .padding(.vertical, 10)
                }
                column(zone)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func column(_ zone: Zone) -> some View {
        let date = entry.displayDate
        let offset = ZoneClock.offsetMinutes(of: zone.timeZone, from: .current, at: date)
        let sun = SolarPosition(date: date)
        let daylight = zone.location.map { ZoneClock.daylight(at: $0, sun: sun) } ?? .day
        return VStack(spacing: 6) {
            Image(systemName: daylight.symbolName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 14))
            Text(zone.cityName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(ZoneClock.time(date, in: zone.timeZone))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(entry.isShifted ? Color.sunlight : Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .widgetAccentable()
            Text(ZoneClock.offsetLabel(minutes: offset))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
    }
}
