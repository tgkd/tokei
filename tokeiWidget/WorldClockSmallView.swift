import SwiftUI
import WidgetKit

struct WorldClockSmallView: View {
    @Environment(\.widgetLook) private var look

    let entry: ClockEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(entry.zones.prefix(3)) { zone in
                Link(destination: URL(string: "tokei://zone/\(zone.id.uuidString)")!) {
                    ZoneClockLine(zone: zone, date: entry.displayDate, homeZone: entry.homeZone, isShifted: entry.isShifted)
                }
            }
            Spacer(minLength: 0)
            if entry.isShifted {
                Text(ZoneClock.shiftLabel(minutes: entry.shiftMinutes))
                    .font(look.typography.title.font(size: 11))
                    .monospacedDigit()
                    .foregroundStyle(look.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
