import SwiftUI
import WidgetKit

struct WorldClockLargeView: View {
    @Environment(\.widgetLook) private var look

    let entry: ClockEntry

    var body: some View {
        VStack(spacing: 0) {
            DayNightMapView(entry: entry)
                .frame(height: 160)
                .invalidatableContent()
            VStack(spacing: 0) {
                ForEach(entry.zones.prefix(4)) { zone in
                    Link(destination: URL(string: "tokei://zone/\(zone.id.uuidString)")!) {
                        row(zone)
                            .invalidatableContent()
                    }
                    if zone.id != entry.zones.prefix(4).last?.id {
                        Rectangle()
                            .fill(look.rule)
                            .frame(height: 0.5)
                    }
                }
                Spacer(minLength: 0)
                HStack {
                    Text(ZoneClock.weekdayAndDate(entry.displayDate, in: entry.homeZone))
                        .caption(look, size: 11)
                        .textCase(look.typography.uppercasedCaptions ? .uppercase : nil)
                        .foregroundStyle(look.faintInk)
                        .invalidatableContent()
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
        let date = entry.displayDate
        let offset = ZoneClock.offsetMinutes(of: zone.timeZone, from: entry.homeZone, at: date)
        let day = ZoneClock.dayDeltaLabel(ZoneClock.dayDelta(of: zone.timeZone, from: entry.homeZone, at: date))
        let detail = [day, ZoneClock.offsetLabel(minutes: offset)].compactMap { $0 }.joined(separator: " · ")
        return HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text(zone.cityName)
                    .font(look.typography.title.font(size: 14))
                    .foregroundStyle(look.ink)
                Text(detail)
                    .caption(look, size: 11)
                    .foregroundStyle(look.faintInk)
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            Text(ZoneClock.time(date, in: zone.timeZone))
                .font(look.typography.digits.font(size: 22))
                .monospacedDigit()
                .foregroundStyle(entry.isShifted ? look.accent : look.ink)
                .widgetAccentable()
        }
        .padding(.vertical, 6)
    }
}
