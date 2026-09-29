import simd

@MainActor
struct CloudPresence {
    let map: CloudMap
    let snow: SnowCover?
    let clock: Double
    let recovery: Double

    init?(frame: GlobeFrame, snow: SnowCover?) {
        guard let weather = frame.weather, let settings = frame.style.mesh?.snow else { return nil }
        map = weather.map
        self.snow = snow
        clock = frame.effects.snowClock
        recovery = settings.recovery
    }

    func covers(_ direction: SIMD3<Double>) -> Bool {
        let refill = snow?.level(at: direction, clock: clock, recovery: recovery) ?? 1
        return map.mask(at: direction) - (1 - refill) > 0.5
    }
}
