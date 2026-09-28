import SwiftUI

struct ScrubberPanel: View {
    @Environment(SceneModel.self) private var scene
    @Environment(\.sceneAccent) private var accent

    let now: Date
    let shift: Double

    private var minutes: Int {
        Int(shift.rounded())
    }

    var body: some View {
        let date = now.addingTimeInterval(shift * 60)
        let zone = TimeZone.current
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(ZoneClock.time(date, in: zone))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(minutes == 0 ? Color.white : accent)
                    Text("\(ZoneClock.weekdayAndDate(date, in: zone)) · \(Zone.cityName(for: zone.identifier))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                trailing
            }
            TimeTape(now: now, shift: shift)
                .frame(height: 46)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 30))
    }

    @ViewBuilder
    private var trailing: some View {
        if minutes == 0 {
            Text("Now")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(height: 36)
        } else {
            Button {
                scene.resetShift()
            } label: {
                HStack(spacing: 6) {
                    Text(ZoneClock.shiftLabel(minutes: minutes))
                        .monospacedDigit()
                    Image(systemName: "arrow.uturn.backward")
                        .font(.caption.weight(.bold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .background(accent, in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to now")
        }
    }
}
