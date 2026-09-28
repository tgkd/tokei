import SwiftUI

struct ScrubberPanel: View {
    @Environment(SceneModel.self) private var scene
    @Environment(\.sceneAccent) private var accent
    @Environment(\.sceneStyle) private var style
    @ScaledMetric(relativeTo: .largeTitle) private var timeSize: CGFloat = 34

    let now: Date
    let shift: Double
    let homeZone: TimeZone

    private var minutes: Int {
        Int(shift.rounded())
    }

    var body: some View {
        let interface = style.interface
        let typography = interface.typography
        let date = now.addingTimeInterval(shift * 60)
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    DisplayTime(date: date, zone: homeZone, font: typography.display(size: timeSize), periodFont: typography.period(size: timeSize * 0.5))
                        .foregroundStyle(minutes == 0 ? interface.ink : accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text("\(ZoneClock.weekdayAndDate(date, in: homeZone)) · \(Zone.cityName(for: homeZone.identifier))")
                        .font(typography.caption(.footnote))
                        .textCase(typography.captionCase)
                        .tracking(typography.captionTracking)
                        .foregroundStyle(interface.secondaryInk)
                        .lineLimit(1)
                }
                .engraved(typography.engraved)
                Spacer(minLength: 8)
                trailing(interface)
            }
            TimeTape(now: now, shift: shift, homeZone: homeZone)
                .frame(height: 46)
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .surface(interface.panel, in: .rect(cornerRadius: interface.panelCorner, style: .continuous))
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    @ViewBuilder
    private func trailing(_ interface: InterfaceLook) -> some View {
        if minutes == 0 {
            Text("Now")
                .font(interface.typography.title(.subheadline))
                .foregroundStyle(interface.secondaryInk)
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
                .font(interface.typography.title(.subheadline))
                .foregroundStyle(interface.onAccent)
                .padding(.horizontal, 12)
                .frame(height: 34)
                .contentShape(.capsule)
            }
            .buttonStyle(SurfaceButtonStyle(surface: interface.accentSurface, shape: Capsule()))
            .frame(minHeight: 44)
            .contentShape(.rect)
            .accessibilityLabel("Back to now")
        }
    }
}
