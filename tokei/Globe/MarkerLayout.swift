import CoreGraphics
import Foundation

struct MarkerItem: Identifiable {
    let zone: Zone
    let anchor: CGPoint
    let fade: Double
    let time: String
    let detail: String?
    let chipFrame: CGRect?

    var id: UUID {
        zone.id
    }
}

final class MarkerLayoutCache {
    var candidates: [UUID: Int] = [:]
    private var sizes: [String: CGSize] = [:]

    func size(name: String, time: String, detail: String?) -> CGSize {
        let key = [name, time, detail ?? ""].joined(separator: "|")
        if let size = sizes[key] {
            return size
        }
        if sizes.count > 256 {
            sizes.removeAll()
        }
        let size = ChipMetrics.size(name: name, time: time, detail: detail)
        sizes[key] = size
        return size
    }
}

enum MarkerLayout {
    static func items(
        zones: [Zone],
        frame: GlobeFrame,
        date: Date,
        selection: UUID?,
        bounds: CGRect,
        cache: MarkerLayoutCache
    ) -> [MarkerItem] {
        let local = TimeZone.current
        var visible: [(zone: Zone, anchor: CGPoint, fade: Double)] = []
        for zone in zones {
            guard let location = zone.location else { continue }
            let point = location.unitVector
            let facing = frame.visibility(of: point)
            guard facing > 0, let anchor = frame.project(point) else { continue }
            visible.append((zone, anchor, min(facing / 0.2, 1)))
        }

        let ordered = visible.sorted { lhs, rhs in
            (lhs.zone.id == selection ? 0 : 1) < (rhs.zone.id == selection ? 0 : 1)
        }

        var texts: [UUID: (time: String, detail: String?)] = [:]
        var requests: [LabelRequest] = []
        for entry in ordered {
            let zone = entry.zone
            let time = ZoneClock.time(date, in: zone.timeZone)
            var detail: String?
            if zone.id == selection {
                let offset = ZoneClock.offsetMinutes(of: zone.timeZone, from: local, at: date)
                let day = ZoneClock.dayDeltaLabel(ZoneClock.dayDelta(of: zone.timeZone, from: local, at: date))
                detail = [day, ZoneClock.offsetLabel(minutes: offset)].compactMap { $0 }.joined(separator: " · ")
            }
            texts[zone.id] = (time, detail)
            guard entry.fade > 0.45 else { continue }
            let size = cache.size(name: zone.cityName, time: time, detail: detail)
            requests.append(LabelRequest(id: zone.id, anchor: entry.anchor, size: size, previousCandidate: cache.candidates[zone.id]))
        }

        let placements = LabelPlacer.place(
            requests,
            in: bounds,
            dotRadius: ChipMetrics.dotRadius,
            gap: ChipMetrics.gap,
            spacing: 3,
            entrySpacing: 9
        )
        cache.candidates = placements.mapValues(\.candidate)

        return visible.map { entry in
            let text = texts[entry.zone.id]
            return MarkerItem(
                zone: entry.zone,
                anchor: entry.anchor,
                fade: entry.fade,
                time: text?.time ?? "",
                detail: text?.detail,
                chipFrame: placements[entry.zone.id]?.frame
            )
        }
    }
}
