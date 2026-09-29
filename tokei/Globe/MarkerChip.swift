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
        .padding(.horizontal, chip.horizontalPadding)
        .padding(.vertical, chip.verticalPadding)
        .surface(
            filled ?? chip.surface,
            in: RoundedRectangle(cornerRadius: chip.corner, style: .continuous),
            outline: isSelected && filled == nil ? accent : nil,
            outlineWidth: 1.25
        )
    }
}
