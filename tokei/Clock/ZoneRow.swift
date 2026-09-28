import SwiftUI

struct ZoneRow: View {
    @Environment(\.sceneAccent) private var accent
    @Environment(\.sceneStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var timeSize: CGFloat = 28

    let zone: Zone
    let date: Date
    let homeZone: TimeZone
    let isShifted: Bool
    let isSelected: Bool

    var body: some View {
        let interface = style.interface
        let typography = interface.typography
        let offset = ZoneClock.offsetMinutes(of: zone.timeZone, from: homeZone, at: date)
        let day = ZoneClock.dayDeltaLabel(ZoneClock.dayDelta(of: zone.timeZone, from: homeZone, at: date))
        let subtitle = [day, ZoneClock.offsetLabel(minutes: offset)].compactMap { $0 }.joined(separator: " · ")
        let light = daylight(sun: SolarPosition(date: date))
        let stacked = dynamicTypeSize.isAccessibilitySize
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(spacing: 14))

        layout {
            HStack(spacing: 14) {
                Image(systemName: light.symbolName)
                    .symbolRenderingMode(light == .night ? .hierarchical : .multicolor)
                    .foregroundStyle(interface.secondaryInk)
                    .font(.system(size: 20, weight: typography.symbolWeight))
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(zone.cityName)
                        .font(typography.title(.headline))
                        .foregroundStyle(isSelected ? accent : interface.ink)
                        .lineLimit(stacked ? 2 : 1)
                    Text(subtitle)
                        .font(typography.caption(.subheadline))
                        .tracking(typography.captionTracking)
                        .foregroundStyle(interface.secondaryInk)
                        .lineLimit(stacked ? 2 : 1)
                }
            }
            if !stacked {
                Spacer(minLength: 8)
            }
            DisplayTime(date: date, zone: zone.timeZone, font: typography.display(size: timeSize), periodFont: typography.period(size: timeSize * 0.52))
                .foregroundStyle(isShifted ? accent : interface.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.leading, stacked ? 44 : 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func daylight(sun: SolarPosition) -> Daylight {
        guard let location = zone.location else { return .day }
        return ZoneClock.daylight(at: location, sun: sun)
    }
}
