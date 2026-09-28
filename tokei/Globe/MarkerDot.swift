import SwiftUI

struct MarkerDot: View {
    @Environment(\.sceneAccent) private var accent

    let isSelected: Bool

    var body: some View {
        Circle()
            .fill(isSelected ? accent : Color.white)
            .frame(width: ChipMetrics.dotRadius * 2, height: ChipMetrics.dotRadius * 2)
            .overlay {
                Circle().strokeBorder(.black.opacity(0.55), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.6), radius: 2)
    }
}
