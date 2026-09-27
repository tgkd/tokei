import CoreGraphics
import Foundation
import WidgetKit

struct ClockProvider: TimelineProvider {
    let includesMap: Bool

    func placeholder(in context: Context) -> ClockEntry {
        makeEntry(at: Date(), zones: Zone.defaults, shift: 0, family: context.family)
    }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(makeEntry(at: Date(), zones: loadZones(), shift: ZoneStorage.loadShift(), family: context.family))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let zones = loadZones()
        let shift = ZoneStorage.loadShift()
        let now = Date().timeIntervalSince1970
        let start = Date(timeIntervalSince1970: (now / 60).rounded(.down) * 60)
        let entries = (0..<60).map { index in
            makeEntry(
                at: start.addingTimeInterval(TimeInterval(index * 60)),
                zones: zones,
                shift: shift,
                family: context.family
            )
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(at date: Date, zones: [Zone], shift: Int, family: WidgetFamily) -> ClockEntry {
        var mask: CGImage?
        if includesMap && (family == .systemMedium || family == .systemLarge) {
            let displayDate = date.addingTimeInterval(TimeInterval(shift * 60))
            mask = MaskCache.shared.mask(for: displayDate, centerLongitude: ClockEntry.mapCenterLongitude)
        }
        return ClockEntry(date: date, zones: zones, shiftMinutes: shift, nightMask: mask)
    }

    private func loadZones() -> [Zone] {
        let zones = ZoneStorage.loadZones()
        return zones.isEmpty ? [Zone.local] : zones
    }
}

final class MaskCache: @unchecked Sendable {
    static let shared = MaskCache()

    private let lock = NSLock()
    private var images: [Key: CGImage] = [:]

    private struct Key: Hashable {
        let bucket: Int
        let centerLongitude: Double
    }

    func mask(for date: Date, centerLongitude: Double) -> CGImage? {
        let bucket = Int((date.timeIntervalSince1970 / 300).rounded())
        let key = Key(bucket: bucket, centerLongitude: centerLongitude)
        if let image = lock.withLock({ images[key] }) {
            return image
        }
        let image = NightMask.image(for: Date(timeIntervalSince1970: TimeInterval(bucket * 300)), centerLongitude: centerLongitude)
        lock.withLock {
            if images.count > 200 {
                images.removeAll()
            }
            images[key] = image
        }
        return image
    }
}
