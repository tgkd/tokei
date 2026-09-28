import SwiftUI

struct MarkerChip: View {
    @Environment(\.sceneAccent) private var accent

    let name: String
    let time: String
    let detail: String?
    let isSelected: Bool
    let isShifted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ChipMetrics.lineSpacing) {
            HStack(spacing: ChipMetrics.spacing) {
                Text(name)
                    .font(Font(ChipMetrics.nameFont))
                    .foregroundStyle(.white)
                Text(time)
                    .font(Font(ChipMetrics.timeFont))
                    .foregroundStyle(isShifted ? accent : Color.white.opacity(0.72))
            }
            if let detail {
                Text(detail)
                    .font(Font(ChipMetrics.detailFont))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, ChipMetrics.horizontalPadding)
        .padding(.vertical, ChipMetrics.verticalPadding)
        .background(.black.opacity(0.56), in: .rect(cornerRadius: detail == nil ? 13 : 11))
        .overlay {
            RoundedRectangle(cornerRadius: detail == nil ? 13 : 11)
                .strokeBorder(isSelected ? accent.opacity(0.9) : Color.white.opacity(0.14), lineWidth: isSelected ? 1 : 0.5)
        }
    }
}
