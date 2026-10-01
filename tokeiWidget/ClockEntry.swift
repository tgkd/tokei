import CoreGraphics
import Foundation
import WidgetKit

struct ClockEntry: TimelineEntry {
    let date: Date
    let zones: [Zone]
    let shiftMinutes: Int
    let homeZone: TimeZone
    let look: WidgetLook
    let nightMask: CGImage?
    let pixelMap: PixelMap?

    var displayDate: Date {
        date.addingTimeInterval(TimeInterval(shiftMinutes * 60))
    }

    var isShifted: Bool {
        shiftMinutes != 0
    }

    static func mapCenterLongitude(for homeZone: TimeZone) -> Double {
        ZoneCoordinates.point(for: homeZone.identifier)?.longitude ?? 0
    }
}
