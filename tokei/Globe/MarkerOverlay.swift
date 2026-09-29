import SwiftUI

struct MarkerOverlay: View {
    let items: [MarkerItem]
    let selection: UUID?
    let isShifted: Bool
    let onSelect: (UUID) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(items) { item in
                MarkerDot(isSelected: item.id == selection)
                    .position(item.anchor)
                    .opacity(item.fade)
                    .allowsHitTesting(false)
                if let chipFrame = item.chipFrame {
                    Button {
                        onSelect(item.id)
                    } label: {
                        MarkerChip(
                            name: item.zone.cityName,
                            time: item.time,
                            detail: item.detail,
                            weather: item.weather,
                            isSelected: item.id == selection,
                            isShifted: isShifted
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(width: chipFrame.width, height: chipFrame.height)
                    .position(x: chipFrame.midX, y: chipFrame.midY)
                    .opacity(item.fade)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .transaction { $0.animation = nil }
    }
}
