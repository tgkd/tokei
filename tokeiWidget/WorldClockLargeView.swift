import SwiftUI
import WidgetKit

struct WorldClockLargeView: View {
    let entry: ClockEntry

    var body: some View {
        VStack(spacing: 0) {
            DayNightMapView(entry: entry)
                .frame(height: 160)
            VStack(spacing: 0) {
                ForEach(entry.zones.prefix(4)) { zone in
                    Link(destination: URL(string: "tokei://zone/\(zone.id.uuidString)")!) {
                        row(zone)
                    }
                    if zone.id != entry.zones.prefix(4).last?.id {
                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(height: 0.5)
                    }
                }
                Spacer(minLength: 0)
                HStack {
                    Text(ZoneClock.weekdayAndDate(entry.displayDate, in: .current))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    ShiftControls(shiftMinutes: entry.shiftMinutes)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }

    private func row(_ zone: Zone) -> some View {
        let local = TimeZone.current
        let date = entry.displayDate
        let offset = ZoneClock.offsetMinutes(of: zone.timeZone, from: local, at: date)
        let day = ZoneClock.dayDeltaLabel(ZoneClock.dayDelta(of: zone.timeZone, from: local, at: date))
        let detail = [day, ZoneClock.offsetLabel(minutes: offset)].compactMap { $0 }.joined(separator: " · ")
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text(zone.cityName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            Text(ZoneClock.time(date, in: zone.timeZone))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(entry.isShifted ? Color.sunlight : Color.white)
                .widgetAccentable()
        }
        .padding(.vertical, 6)
    }
}
