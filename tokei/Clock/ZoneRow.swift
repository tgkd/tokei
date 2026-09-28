import SwiftUI

struct ZoneRow: View {
    @Environment(\.sceneAccent) private var accent

    let zone: Zone
    let date: Date
    let isShifted: Bool
    let isSelected: Bool

    var body: some View {
        let local = TimeZone.current
        let offset = ZoneClock.offsetMinutes(of: zone.timeZone, from: local, at: date)
        let day = ZoneClock.dayDeltaLabel(ZoneClock.dayDelta(of: zone.timeZone, from: local, at: date))
        let subtitle = [day, ZoneClock.offsetLabel(minutes: offset)].compactMap { $0 }.joined(separator: " · ")
        let sun = SolarPosition(date: date)

        HStack(spacing: 14) {
            Image(systemName: daylight(sun: sun).symbolName)
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 20))
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(zone.cityName)
                    .font(.headline)
                    .foregroundStyle(isSelected ? accent : Color.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(ZoneClock.time(date, in: zone.timeZone))
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isShifted ? accent : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func daylight(sun: SolarPosition) -> Daylight {
        guard let location = zone.location else { return .day }
        return ZoneClock.daylight(at: location, sun: sun)
    }
}
