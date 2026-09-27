import CoreGraphics
import Foundation
import WidgetKit

struct ClockProvider: TimelineProvider {
    let includesMap: Bool

    func placeholder(in context: Context) -> ClockEntry {
        makeEntry(at: Date(), zones: Zone.defaults, shift: 0, family: context.family, masks: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(makeEntry(at: Date(), zones: loadZones(), shift: ZoneStorage.loadShift(), family: context.family, masks: nil))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let zones = loadZones()
        let shift = ZoneStorage.loadShift()
        let now = Date().timeIntervalSince1970
        let start = Date(timeIntervalSince1970: (now / 60).rounded(.down) * 60)
        let masks = MaskCache()
        let entries = (0..<180).map { index in
            makeEntry(
                at: start.addingTimeInterval(TimeInterval(index * 60)),
                zones: zones,
                shift: shift,
                family: context.family,
                masks: masks
            )
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(at date: Date, zones: [Zone], shift: Int, family: WidgetFamily, masks: MaskCache?) -> ClockEntry {
        var mask: CGImage?
        if includesMap && (family == .systemMedium || family == .systemLarge) {
            let displayDate = date.addingTimeInterval(TimeInterval(shift * 60))
            mask = (masks ?? MaskCache()).mask(for: displayDate)
        }
        return ClockEntry(date: date, zones: zones, shiftMinutes: shift, nightMask: mask)
    }

    private func loadZones() -> [Zone] {
        let zones = ZoneStorage.loadZones()
        return zones.isEmpty ? [Zone.local] : zones
    }
}

final class MaskCache {
    private var images: [Int: CGImage] = [:]
    private let center = ClockEntry.mapCenterLongitude

    func mask(for date: Date) -> CGImage? {
        let bucket = Int((date.timeIntervalSince1970 / 300).rounded())
        if let image = images[bucket] {
            return image
        }
        let image = NightMask.image(for: Date(timeIntervalSince1970: TimeInterval(bucket * 300)), centerLongitude: center)
        images[bucket] = image
        return image
    }
}
