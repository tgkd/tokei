import SwiftUI
import WidgetKit

struct ZoneClockLine: View {
    @Environment(\.widgetLook) private var look

    let zone: Zone
    let date: Date
    let homeZone: TimeZone
    let isShifted: Bool
    var timeSize: CGFloat = 20

    var body: some View {
        let delta = ZoneClock.dayDelta(of: zone.timeZone, from: homeZone, at: date)
        VStack(alignment: .leading, spacing: 0) {
            Text(zone.cityName)
                .font(look.typography.title.font(size: 11))
                .foregroundStyle(look.secondaryInk)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(ZoneClock.time(date, in: zone.timeZone))
                    .font(look.typography.digits.font(size: timeSize))
                    .monospacedDigit()
                    .foregroundStyle(isShifted ? look.accent : look.ink)
                    .widgetAccentable()
                if delta != 0 {
                    Text(delta > 0 ? "+\(delta)" : "−\(abs(delta))")
                        .font(look.typography.title.font(size: 10))
                        .foregroundStyle(look.faintInk)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
    }
}
