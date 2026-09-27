import Foundation

struct Zone: Identifiable, Codable, Hashable {
    let id: UUID
    var cityName: String
    var timeZoneIdentifier: String

    init(id: UUID = UUID(), cityName: String, timeZoneIdentifier: String) {
        self.id = id
        self.cityName = cityName
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    var location: GeoPoint? {
        ZoneCoordinates.point(for: timeZoneIdentifier)
    }

    static func cityName(for identifier: String) -> String {
        let last = identifier.split(separator: "/").last.map(String.init) ?? identifier
        return last.replacingOccurrences(of: "_", with: " ")
    }

    static func regionName(for identifier: String) -> String {
        let parts = identifier.split(separator: "/")
        guard parts.count > 1 else { return "" }
        return parts.dropLast().joined(separator: " · ").replacingOccurrences(of: "_", with: " ")
    }

    static var local: Zone {
        let identifier = TimeZone.current.identifier
        return Zone(
            id: UUID(uuidString: "5E1F0000-0000-4000-8000-000000000000")!,
            cityName: cityName(for: identifier),
            timeZoneIdentifier: identifier
        )
    }

    static let defaults: [Zone] = [
        Zone(
            id: UUID(uuidString: "D0000000-0000-4000-8000-000000000001")!,
            cityName: "Yekaterinburg",
            timeZoneIdentifier: "Asia/Yekaterinburg"
        ),
        Zone(
            id: UUID(uuidString: "D0000000-0000-4000-8000-000000000002")!,
            cityName: "London",
            timeZoneIdentifier: "Europe/London"
        ),
        Zone(
            id: UUID(uuidString: "D0000000-0000-4000-8000-000000000003")!,
            cityName: "Buenos Aires",
            timeZoneIdentifier: "America/Argentina/Buenos_Aires"
        ),
        Zone(
            id: UUID(uuidString: "D0000000-0000-4000-8000-000000000004")!,
            cityName: "Tokyo",
            timeZoneIdentifier: "Asia/Tokyo"
        ),
    ]
}
