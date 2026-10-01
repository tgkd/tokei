import CoreGraphics
import Foundation
import WidgetKit

struct ClockProvider: TimelineProvider {
    let includesMap: Bool

    func placeholder(in context: Context) -> ClockEntry {
        makeEntry(at: Date(), zones: Zone.defaults, shift: 0, homeZone: .current, look: ZoneStorage.loadWidgetLook(), context: context)
    }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        let homeZone = ZoneStorage.loadHomeZone()
        completion(makeEntry(
            at: Date(),
            zones: loadZones(homeZone: homeZone),
            shift: ZoneStorage.loadShift(),
            homeZone: homeZone,
            look: ZoneStorage.loadWidgetLook(),
            context: context
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let homeZone = ZoneStorage.loadHomeZone()
        let zones = loadZones(homeZone: homeZone)
        let shift = ZoneStorage.loadShift()
        let look = ZoneStorage.loadWidgetLook()
        let now = Date().timeIntervalSince1970
        let start = Date(timeIntervalSince1970: (now / 60).rounded(.down) * 60)
        let entries = (0..<60).map { index in
            makeEntry(
                at: start.addingTimeInterval(TimeInterval(index * 60)),
                zones: zones,
                shift: shift,
                homeZone: homeZone,
                look: look,
                context: context
            )
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(at date: Date, zones: [Zone], shift: Int, homeZone: TimeZone, look: WidgetLook, context: Context) -> ClockEntry {
        var mask: CGImage?
        var pixelMap: PixelMap?
        if includesMap && (context.family == .systemMedium || context.family == .systemLarge) {
            let displayDate = date.addingTimeInterval(TimeInterval(shift * 60))
            let center = ClockEntry.mapCenterLongitude(for: homeZone)
            mask = MaskCache.shared.mask(for: displayDate, centerLongitude: center, grid: .smooth)
            if case let .flat(ocean, land, coast, _, pixelSize?) = look.map {
                pixelMap = PixelMap.make(
                    at: displayDate,
                    centerLongitude: center,
                    width: context.displaySize.width,
                    pixelSize: pixelSize,
                    ocean: ocean,
                    land: land,
                    coast: coast
                )
            }
        }
        return ClockEntry(date: date, zones: zones, shiftMinutes: shift, homeZone: homeZone, look: look, nightMask: mask, pixelMap: pixelMap)
    }

    private func loadZones(homeZone: TimeZone) -> [Zone] {
        let zones = ZoneStorage.loadZones()
        return zones.isEmpty ? [Zone.home(for: homeZone)] : zones
    }
}

final class MaskCache: @unchecked Sendable {
    static let shared = MaskCache()

    private let lock = NSLock()
    private var images: [Key: CGImage] = [:]

    private struct Key: Hashable {
        let bucket: Int
        let centerLongitude: Double
        let grid: NightMask.Grid
    }

    func mask(for date: Date, centerLongitude: Double, grid: NightMask.Grid) -> CGImage? {
        let bucket = Int((date.timeIntervalSince1970 / 300).rounded())
        let key = Key(bucket: bucket, centerLongitude: centerLongitude, grid: grid)
        if let image = lock.withLock({ images[key] }) {
            return image
        }
        let image = NightMask.image(for: Date(timeIntervalSince1970: TimeInterval(bucket * 300)), centerLongitude: centerLongitude, grid: grid)
        lock.withLock {
            if images.count > 200 {
                images.removeAll()
            }
            images[key] = image
        }
        return image
    }
}
