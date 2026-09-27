import SwiftUI
import WidgetKit

struct MapMarkers: View {
    let entry: ClockEntry
    let centerLongitude: Double
    let mapSize: CGSize
    let mapTop: CGFloat
    let bounds: CGRect
    let obstacles: [CGRect]

    var body: some View {
        let markers = layout()
        ZStack(alignment: .topLeading) {
            ForEach(markers) { marker in
                Circle()
                    .fill(.white)
                    .overlay {
                        Circle().strokeBorder(.black.opacity(0.55), lineWidth: 0.75)
                    }
                    .frame(width: MapLabelMetrics.dotRadius * 2, height: MapLabelMetrics.dotRadius * 2)
                    .position(marker.anchor)
                if let frame = marker.labelFrame {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(marker.name)
                            .font(Font(MapLabelMetrics.nameFont))
                            .foregroundStyle(.white.opacity(0.8))
                        Text(marker.time)
                            .font(Font(MapLabelMetrics.timeFont))
                            .foregroundStyle(entry.isShifted ? Color.sunlight : Color.white)
                    }
                    .lineLimit(1)
                    .fixedSize()
                    .frame(width: frame.width, height: frame.height)
                    .background(.black.opacity(0.55), in: .rect(cornerRadius: 6))
                    .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private struct Marker: Identifiable {
        let id: UUID
        let name: String
        let time: String
        let anchor: CGPoint
        let labelFrame: CGRect?
    }

    private func layout() -> [Marker] {
        var anchors: [(zone: Zone, anchor: CGPoint)] = []
        for zone in entry.zones {
            guard let location = zone.location else { continue }
            let longitude = (location.longitude - centerLongitude + 540).truncatingRemainder(dividingBy: 360)
            let x = CGFloat(longitude / 360) * mapSize.width
            let y = mapTop + CGFloat((90 - location.latitude) / 180) * mapSize.height
            anchors.append((zone, CGPoint(x: x, y: y)))
        }
        let requests = anchors.map { item in
            LabelRequest(
                id: item.zone.id,
                anchor: item.anchor,
                size: MapLabelMetrics.size(name: item.zone.cityName, time: ZoneClock.time(entry.displayDate, in: item.zone.timeZone)),
                previousCandidate: nil
            )
        }
        let placements = LabelPlacer.place(
            requests,
            in: bounds,
            dotRadius: MapLabelMetrics.dotRadius,
            gap: 3,
            spacing: 2,
            entrySpacing: 2,
            obstacles: obstacles
        )
        return anchors.map { item in
            Marker(
                id: item.zone.id,
                name: item.zone.cityName,
                time: ZoneClock.time(entry.displayDate, in: item.zone.timeZone),
                anchor: item.anchor,
                labelFrame: placements[item.zone.id]?.frame
            )
        }
    }
}
