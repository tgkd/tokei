import SwiftUI
import WidgetKit

struct ZoneClockLine: View {
    let zone: Zone
    let date: Date
    let homeZone: TimeZone
    let isShifted: Bool
    var timeSize: CGFloat = 20

    var body: some View {
        let delta = ZoneClock.dayDelta(of: zone.timeZone, from: homeZone, at: date)
        VStack(alignment: .leading, spacing: 0) {
            Text(zone.cityName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(ZoneClock.time(date, in: zone.timeZone))
                    .font(.system(size: timeSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isShifted ? Color.sunlight : Color.white)
                    .widgetAccentable()
                if delta != 0 {
                    Text(delta > 0 ? "+\(delta)" : "−\(abs(delta))")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
        }
    }
}
