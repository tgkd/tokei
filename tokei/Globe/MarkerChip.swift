import SwiftUI

struct MarkerChip: View {
    @Environment(\.sceneStyle) private var style
    @Environment(\.sceneAccent) private var accent

    let name: String
    let time: String
    let detail: String?
    let weather: ChipWeather?
    let isSelected: Bool
    let isShifted: Bool
    let isStriking: Bool

    var body: some View {
        let chip = style.interface.chip
        let fonts = ChipMetrics.fonts(for: style)
        let filled = isSelected ? chip.selectedSurface : nil
        let ink = filled == nil ? nil : chip.selectedInk
        VStack(alignment: .leading, spacing: chip.lineSpacing) {
            HStack(spacing: chip.spacing) {
                Text(ChipMetrics.displayName(name, style: style))
                    .font(Font(fonts.name))
                    .foregroundStyle(ink ?? chip.nameColor)
                Text(time)
                    .font(Font(fonts.time))
                    .foregroundStyle(ink ?? (isShifted ? chip.shiftedTimeColor ?? accent : chip.timeColor))
            }
            if let detail {
                Text(detail)
                    .font(Font(fonts.detail))
                    .foregroundStyle(ink ?? chip.detailColor)
            }
            if let weather {
                HStack(spacing: ChipMetrics.weatherSpacing) {
                    Image(systemName: weather.symbol)
                        .symbolRenderingMode(.hierarchical)
                    if !weather.text.isEmpty {
                        Text(weather.text)
                            .monospacedDigit()
                    }
                }
                .font(Font(fonts.detail))
                .foregroundStyle(ink ?? chip.detailColor)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(weather.accessibilityLabel)
            }
        }
        .lineLimit(1)
        .fixedSize()
        .padding(ChipMetrics.padding(chip, isExpanded: detail != nil || weather != nil))
        .surface(
            filled ?? chip.surface,
            in: RoundedRectangle(cornerRadius: ChipMetrics.corner(chip, isExpanded: detail != nil || weather != nil), style: .continuous),
            outline: isSelected && filled == nil ? accent : nil,
            outlineWidth: 1.25
        )
        .keyframeAnimator(initialValue: 0.0, trigger: isSelected) { content, angle in
            content.rotation3DEffect(.degrees(chip.flipsOnSelect ? angle : 0), axis: (x: 1, y: 0, z: 0))
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(90, duration: 0.12)
                CubicKeyframe(0, duration: 0.16)
            }
        }
        .scaleEffect(isStriking ? 1.07 : 1)
        .animation(.spring(duration: 0.35, bounce: 0.3), value: isStriking)
        .overlay {
            if isStriking {
                RoundedRectangle(cornerRadius: ChipMetrics.corner(chip, isExpanded: detail != nil || weather != nil), style: .continuous)
                    .stroke(accent, lineWidth: 1.5)
                    .padding(1.5)
            }
        }
    }
}
