import AppIntents
import SwiftUI
import WidgetKit

struct ShiftControls: View {
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
                    .foregroundStyle(shiftMinutes == 0 ? Color.white.opacity(0.85) : Color.sunlight)
                    .padding(.horizontal, 6)
                    .frame(minWidth: 44, minHeight: 26)
            }
            Button(intent: AdjustTimeIntent(minutes: stepMinutes)) {
                Image(systemName: "plus")
                    .frame(width: 30, height: 26)
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .background(.black.opacity(0.5), in: .capsule)
        .overlay {
            Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
        }
    }
}
