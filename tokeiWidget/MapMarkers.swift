import SwiftUI
import WidgetKit

struct MapMarkers: View {
    @Environment(\.widgetLook) private var look

    let entry: ClockEntry
    let centerLongitude: Double
    let mapSize: CGSize
    let mapTop: CGFloat
    let bounds: CGRect
    let obstacles: [CGRect]

    var body: some View {
        let markers = layout()
        let typography = look.typography
        let label = look.label
        ZStack(alignment: .topLeading) {
            ForEach(markers) { marker in
                Circle()
                    .fill(look.dot.fill)
                    .overlay {
                        Circle().strokeBorder(look.dot.outline, lineWidth: look.dot.outlineWidth)
                    }
                    .frame(width: MapLabelMetrics.dotRadius * 2, height: MapLabelMetrics.dotRadius * 2)
                    .position(marker.anchor)
                if let frame = marker.labelFrame {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(marker.name)
                            .font(Font(MapLabelMetrics.nameFont(typography)))
                            .foregroundStyle(label.nameColor)
                        Text(marker.time)
                            .font(Font(MapLabelMetrics.timeFont(typography)))
                            .foregroundStyle(entry.isShifted ? label.shiftedTimeColor : label.timeColor)
                    }
                    .lineLimit(1)
                    .fixedSize()
                    .frame(width: frame.width, height: frame.height)
                    .widgetSurface(label.surface, in: RoundedRectangle(cornerRadius: MapLabelMetrics.corner(label)))
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
                size: MapLabelMetrics.size(
                    name: name(of: item.zone),
                    time: ZoneClock.time(entry.displayDate, in: item.zone.timeZone),
                    typography: look.typography,
                    corner: MapLabelMetrics.corner(look.label)
                ),
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
                name: name(of: item.zone),
                time: ZoneClock.time(entry.displayDate, in: item.zone.timeZone),
                anchor: item.anchor,
                labelFrame: placements[item.zone.id]?.frame
            )
        }
    }

    private func name(of zone: Zone) -> String {
        look.typography.uppercasedLabelNames ? zone.cityName.uppercased() : zone.cityName
    }
}
