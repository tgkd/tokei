import CoreGraphics
import Foundation

struct MarkerItem: Identifiable {
    let zone: Zone
    let anchor: CGPoint
    let fade: Double
    let time: String
    let detail: String?
    let weather: ChipWeather?
    let chipFrame: CGRect?

    var id: UUID {
        zone.id
    }
}

final class MarkerLayoutCache {
    var candidates: [UUID: Int] = [:]
    private var sizes: [String: CGSize] = [:]

    func size(name: String, time: String, detail: String?, weather: ChipWeather?, style: SceneStyle) -> CGSize {
        let key = [style.rawValue, name, time, detail ?? "", weather?.symbol ?? "", weather?.text ?? ""].joined(separator: "|")
        if let size = sizes[key] {
            return size
        }
        if sizes.count > 256 {
            sizes.removeAll()
        }
        let size = ChipMetrics.size(name: name, time: time, detail: detail, weather: weather, style: style)
        sizes[key] = size
        return size
    }
}

enum MarkerLayout {
    @MainActor
    static func items(
        zones: [Zone],
        frame: GlobeFrame,
        date: Date,
        homeZone: TimeZone,
        selection: UUID?,
        bounds: CGRect,
        surface: ToySurface?,
        clouds: CloudPresence?,
        weatherStatus: WeatherFeed.Status,
        cache: MarkerLayoutCache
    ) -> [MarkerItem] {
        var visible: [(zone: Zone, anchor: CGPoint, fade: Double)] = []
        let cloudTop = CloudShell.lift(inflate: frame.effects.inflate)
        for zone in zones {
            guard let location = zone.location else { continue }
            let unit = location.unitVector
            let ground = frame.effects.place(unit, surfaceRadius: surface?.radius(along: unit, in: frame) ?? 1)
            let facing = frame.visibility(of: ground)
            guard facing > 0 else { continue }
            let point = clouds?.covers(unit) == true ? frame.effects.place(unit, lift: cloudTop) : ground
            guard let anchor = frame.project(point) else { continue }
            visible.append((zone, anchor, min(facing / 0.2, 1)))
        }

        let ordered = visible.sorted { lhs, rhs in
            (lhs.zone.id == selection ? 0 : 1) < (rhs.zone.id == selection ? 0 : 1)
        }

        var texts: [UUID: (time: String, detail: String?, weather: ChipWeather?)] = [:]
        var requests: [LabelRequest] = []
        for entry in ordered {
            let zone = entry.zone
            let time = ZoneClock.time(date, in: zone.timeZone)
            var detail: String?
            var weather: ChipWeather?
            if zone.id == selection {
                let offset = ZoneClock.offsetMinutes(of: zone.timeZone, from: homeZone, at: date)
                let day = ZoneClock.dayDeltaLabel(ZoneClock.dayDelta(of: zone.timeZone, from: homeZone, at: date))
                detail = [day, ZoneClock.offsetLabel(minutes: offset)].compactMap { $0 }.joined(separator: " · ")
                if let location = zone.location {
                    weather = ChipWeather.make(frame: frame, direction: location.unitVector, date: date, homeZone: homeZone, status: weatherStatus)
                }
            }
            texts[zone.id] = (time, detail, weather)
            guard entry.fade > 0.45 else { continue }
            let size = cache.size(name: zone.cityName, time: time, detail: detail, weather: weather, style: frame.style)
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
                weather: text?.weather ?? nil,
                chipFrame: placements[entry.zone.id]?.frame
            )
        }
    }
}
