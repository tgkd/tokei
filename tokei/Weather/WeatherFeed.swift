import Foundation
import Observation

@MainActor
@Observable
final class WeatherFeed {
    enum Status: Equatable {
        case idle
        case loading
        case ready
        case updating
        case stale
        case unavailable
    }

    struct Request: Equatable {
        let target: Date
        let attempt: Int
    }

    private(set) var frame: WeatherFrame?
    private(set) var target: Date?
    private(set) var attempt = 0
    private var isFetching = false
    private var hasFailed = false
    @ObservationIgnored private let source = WeatherSource()
    @ObservationIgnored private let cache = WeatherCache()
    @ObservationIgnored private var bundles: [WeatherKey: WeatherBundle] = [:]
    @ObservationIgnored private var recency: [WeatherKey] = []

    private static let memoryLimit = 8
    private static let longestBackoff: TimeInterval = 15 * 60

    var status: Status {
        guard let target else { return .idle }
        if let frame, frame.validDate == target {
            return .ready
        }
        if hasFailed && !isFetching {
            return frame == nil ? .unavailable : .stale
        }
        return frame == nil ? .loading : .updating
    }

    func retry() {
        attempt += 1
    }

    func run(_ request: Request) async {
        let target = request.target
        self.target = target
        hasFailed = false
        var backoff: TimeInterval = 30
        while !Task.isCancelled {
            let now = Date()
            let candidates = WeatherSchedule.candidates(for: target, now: now)
            if let cached = await cachedBundle(among: candidates), frame?.key != cached.key {
                guard let built = await Self.build(cached), !Task.isCancelled else { return }
                frame = built
            }
            guard !Task.isCancelled else { return }
            let current = frame?.validDate == target ? frame?.key : nil
            let wanted = Array(candidates.prefix { $0 != current })
            var next: Date?
            if wanted.isEmpty || candidates.isEmpty {
                hasFailed = current == nil
                next = current.flatMap { WeatherSchedule.refreshDate(after: $0, target: target, now: now) }
            } else {
                isFetching = true
                let bundle = await fetchFirst(of: wanted)
                isFetching = false
                guard !Task.isCancelled else { return }
                if let bundle, let built = await Self.build(bundle) {
                    guard !Task.isCancelled else { return }
                    remember(bundle)
                    frame = built
                    hasFailed = false
                    backoff = 30
                    next = WeatherSchedule.refreshDate(after: built.key, target: target, now: Date())
                } else {
                    hasFailed = current == nil
                    next = Date().addingTimeInterval(backoff)
                    backoff = min(backoff * 2, Self.longestBackoff)
                }
            }
            guard let next else { return }
            try? await Task.sleep(for: .seconds(max(next.timeIntervalSinceNow, 1)))
        }
    }

    private func fetchFirst(of keys: [WeatherKey]) async -> WeatherBundle? {
        for key in keys {
            do {
                let bundle = try await source.bundle(for: key)
                let cache = cache
                Task.detached(priority: .utility) {
                    cache.store(bundle)
                }
                return bundle
            } catch WeatherSource.Failure.missing {
                continue
            } catch {
                return nil
            }
        }
        return nil
    }

    private func cachedBundle(among keys: [WeatherKey]) async -> WeatherBundle? {
        for key in keys {
            if let bundle = bundles[key] {
                return bundle
            }
        }
        let cache = cache
        let stored = await Task.detached(priority: .userInitiated) {
            keys.lazy.compactMap { cache.bundle(for: $0) }.first
        }.value
        if let stored {
            remember(stored)
        }
        return stored
    }

    private func remember(_ bundle: WeatherBundle) {
        bundles[bundle.key] = bundle
        recency.removeAll { $0 == bundle.key }
        recency.append(bundle.key)
        while recency.count > Self.memoryLimit {
            bundles[recency.removeFirst()] = nil
        }
    }

    private static func build(_ bundle: WeatherBundle) async -> WeatherFrame? {
        await Task.detached(priority: .userInitiated) {
            try? WeatherFrame(bundle: bundle)
        }.value
    }
}
