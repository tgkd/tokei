import Foundation
import Observation
import WidgetKit

struct FocusRequest: Equatable {
    let id = UUID()
    let point: GeoPoint
}

@MainActor
@Observable
final class ClockStore {
    private(set) var zones: [Zone]
    private(set) var homeZoneIdentifier: String?
    var now = Date()
    var selection: UUID?
    var focusRequest: FocusRequest?

    init() {
        zones = ZoneStorage.loadZones()
        homeZoneIdentifier = ZoneStorage.loadHomeZoneIdentifier()
    }

    var homeZone: TimeZone {
        ZoneStorage.homeZone(for: homeZoneIdentifier)
    }

    var homeLocation: GeoPoint? {
        ZoneCoordinates.point(for: homeZone.identifier)
    }

    func reload() {
        let stored = ZoneStorage.loadZones()
        if stored != zones {
            zones = stored
        }
        let storedHome = ZoneStorage.loadHomeZoneIdentifier()
        if storedHome != homeZoneIdentifier {
            homeZoneIdentifier = storedHome
        }
        now = Date()
    }

    func add(identifier: String) {
        let zone = Zone(cityName: Zone.cityName(for: identifier), timeZoneIdentifier: identifier)
        zones.append(zone)
        persist()
        focus(on: zone)
    }

    func remove(_ zone: Zone) {
        zones.removeAll { $0.id == zone.id }
        if selection == zone.id {
            selection = nil
        }
        persist()
    }

    func remove(atOffsets offsets: IndexSet) {
        let removed = offsets.map { zones[$0].id }
        zones.remove(atOffsets: offsets)
        if let selection, removed.contains(selection) {
            self.selection = nil
        }
        persist()
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        zones.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    func setHomeZone(identifier: String?) {
        guard identifier != homeZoneIdentifier else { return }
        homeZoneIdentifier = identifier
        ZoneStorage.saveHomeZoneIdentifier(identifier)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func toggleSelection(_ id: UUID) {
        selection = selection == id ? nil : id
    }

    func focus(on zone: Zone) {
        selection = zone.id
        if let point = zone.location {
            focusRequest = FocusRequest(point: point)
        }
    }

    func focusHome() {
        selection = nil
        if let homeLocation {
            focusRequest = FocusRequest(point: homeLocation)
        }
    }

    func runClock() async {
        while !Task.isCancelled {
            now = Date()
            let seconds = now.timeIntervalSince1970
            let wait = (seconds / 60).rounded(.down) * 60 + 60.05 - seconds
            try? await Task.sleep(for: .seconds(wait))
        }
    }

    private func persist() {
        ZoneStorage.saveZones(zones)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
