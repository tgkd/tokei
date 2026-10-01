import AppIntents
import SwiftUI
import WidgetKit

struct ShiftControls: View {
    @Environment(\.widgetLook) private var look

    let shiftMinutes: Int
    var stepMinutes = 60

    var body: some View {
        HStack(spacing: 4) {
            Button(intent: AdjustTimeIntent(minutes: -stepMinutes)) {
                Image(systemName: "minus")
                    .frame(width: 30, height: 26)
            }
            Button(intent: ResetTimeIntent()) {
                Text(ZoneClock.shiftLabel(minutes: shiftMinutes))
                    .monospacedDigit()
                    .foregroundStyle(shiftMinutes == 0 ? Color(look.controlInk).opacity(0.85) : Color(look.controlAccent))
                    .padding(.horizontal, 6)
                    .frame(minWidth: 44, minHeight: 26)
            }
            Button(intent: AdjustTimeIntent(minutes: stepMinutes)) {
                Image(systemName: "plus")
                    .frame(width: 30, height: 26)
            }
        }
        .font(look.typography.title.font(size: 12))
        .foregroundStyle(look.controlInk)
        .buttonStyle(.plain)
        .widgetSurface(look.control, in: Capsule())
    }
}
