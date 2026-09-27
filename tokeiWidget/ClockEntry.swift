import CoreGraphics
import Foundation
import WidgetKit

struct ClockEntry: TimelineEntry {
    let date: Date
    let zones: [Zone]
    let shiftMinutes: Int
    let nightMask: CGImage?

    var displayDate: Date {
        date.addingTimeInterval(TimeInterval(shiftMinutes * 60))
    }

    var isShifted: Bool {
        shiftMinutes != 0
    }

    static var mapCenterLongitude: Double {
        ZoneCoordinates.point(for: TimeZone.current.identifier)?.longitude ?? 0
    }
}
