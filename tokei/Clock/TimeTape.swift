import SwiftUI

struct TimeTape: View {
    @Environment(SceneModel.self) private var scene
    @Environment(\.sceneAccent) private var accent
    @Environment(\.sceneStyle) private var style

    let now: Date
    let shift: Double

    @State private var scrubOrigin: Double?

    static let pointsPerMinute: CGFloat = 56 / 60

    private var displayDate: Date {
        now.addingTimeInterval(shift * 60)
    }

    private var hourIndex: Int {
        Int((displayDate.timeIntervalSince1970 / 3600).rounded(.down))
    }

    var body: some View {
        let tape = style.interface.tape
        Canvas { context, size in
            drawTicks(in: context, size: size, tape: tape)
        }
        .overlay {
            TapeNeedle()
        }
        .contentShape(Rectangle())
        .gesture(scrub)
        .sensoryFeedback(.selection, trigger: hourIndex) { _, _ in
            scene.isScrubbing || scene.shiftGlide != nil
        }
        .onChange(of: hourIndex) { old, new in
            guard scene.isScrubbing || scene.shiftGlide != nil else { return }
            let boundary = Date(timeIntervalSince1970: Double(max(old, new)) * 3600)
            let local = Calendar.current.dateComponents([.hour, .minute], from: boundary)
            scene.emit(local.hour == 0 && local.minute == 0 ? .dayTick : .tick)
        }
        .accessibilityElement()
        .accessibilityLabel("Time shift")
        .accessibilityValue(ZoneClock.shiftLabel(minutes: Int(shift.rounded())))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                scene.nudgeShift(by: 15)
            case .decrement:
                scene.nudgeShift(by: -15)
            @unknown default:
                break
            }
        }
    }

    private var scrub: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if scrubOrigin == nil {
                    scrubOrigin = scene.shift(at: Date())
                }
                guard let scrubOrigin else { return }
                scene.scrub(to: scrubOrigin - Double(value.translation.width / Self.pointsPerMinute))
            }
            .onEnded { value in
                scrubOrigin = nil
                scene.releaseScrub(velocity: -Double(value.velocity.width / Self.pointsPerMinute), now: now)
            }
    }

    private func drawTicks(in context: GraphicsContext, size: CGSize, tape: TapeLook) {
        let zone = TimeZone.current
        let center = size.width / 2
        let needle = displayDate.timeIntervalSince1970
        let span = Double(center / Self.pointsPerMinute) * 60 + 1800
        let quarter: TimeInterval = 900
        var tick = ((needle - span) / quarter).rounded(.down) * quarter
        let baseline = size.height - 3

        while tick <= needle + span {
            let x = center + CGFloat((tick - needle) / 60) * Self.pointsPerMinute
            let fade = max(0, min(1, (center - abs(x - center)) / 44))
            if fade > 0 {
                let date = Date(timeIntervalSince1970: tick)
                let local = Int(tick) + zone.secondsFromGMT(for: date)
                let minuteOfDay = ((local % 86_400) + 86_400) % 86_400 / 60
                let isHour = minuteOfDay % 60 == 0
                let isMidnight = minuteOfDay == 0
                let height: CGFloat = isMidnight ? 18 : (isHour ? 13 : 6)
                var path = Path()
                path.move(to: CGPoint(x: x, y: baseline - height))
                path.addLine(to: CGPoint(x: x, y: baseline))
                let color: Color = isMidnight ? accent : tape.tick
                let opacity = (isHour ? 0.62 : 0.26) * fade
                let cap: CGLineCap = tape.squareCaps ? .butt : .round
                context.stroke(path, with: .color(color.opacity(opacity)), style: StrokeStyle(lineWidth: isHour ? tape.hourWidth : tape.quarterWidth, lineCap: cap))
                if isHour {
                    let label = isMidnight
                        ? date.formatted(.dateTime.weekday(.abbreviated))
                        : date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
                    let clearance = min(1, max(0, (abs(x - center) - 10) / 14))
                    let text = Text(label)
                        .font(.system(size: 11, weight: isMidnight ? .bold : tape.labelWeight, design: tape.labelDesign))
                        .foregroundStyle(isMidnight ? accent.opacity(fade * clearance) : tape.label.opacity(fade * clearance))
                    context.draw(text, at: CGPoint(x: x, y: 8), anchor: .center)
                }
            }
            tick += quarter
        }
    }
}
