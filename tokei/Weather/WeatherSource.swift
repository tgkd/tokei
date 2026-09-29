import Foundation

struct WeatherSource: Sendable {
    enum Failure: Error {
        case missing
        case transport
        case malformed
    }

    static let recordLimit = 2 << 20
    static let indexLimit = 256 << 10

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpMaximumConnectionsPerHost = 6
        session = URLSession(configuration: configuration)
    }

    func bundle(for key: WeatherKey) async throws -> WeatherBundle {
        var failed = false
        for host in WeatherSchedule.hosts {
            do {
                return try await bundle(for: key, on: host)
            } catch is CancellationError {
                throw CancellationError()
            } catch Failure.missing {
                continue
            } catch {
                if Task.isCancelled {
                    throw CancellationError()
                }
                failed = true
            }
        }
        throw failed ? Failure.transport : Failure.missing
    }

    private func bundle(for key: WeatherKey, on host: URL) async throws -> WeatherBundle {
        let index = try await index(for: key, on: host)
        let url = key.fileURL(on: host)
        let records = try await withThrowingTaskGroup(of: (WeatherField, Data?).self) { group in
            for field in WeatherField.allCases {
                let range = index.range(of: field, key: key)
                group.addTask {
                    guard let range else {
                        if field.isRequired {
                            throw Failure.missing
                        }
                        return (field, nil)
                    }
                    do {
                        return (field, try await record(at: url, range: range))
                    } catch {
                        if field.isRequired {
                            throw error
                        }
                        return (field, nil)
                    }
                }
            }
            var records: [WeatherField: Data] = [:]
            for try await (field, data) in group {
                if let data {
                    records[field] = data
                }
            }
            return records
        }
        return WeatherBundle(key: key, records: records)
    }

    private func index(for key: WeatherKey, on host: URL) async throws -> WeatherIndex {
        let url = key.fileURL(on: host).appendingPathExtension("idx")
        let data = try await load(URLRequest(url: url), limit: Self.indexLimit) { http in
            http.statusCode == 200
        }
        guard let text = String(data: data, encoding: .utf8), let index = WeatherIndex(text: text) else {
            throw Failure.malformed
        }
        return index
    }

    private func record(at url: URL, range: ClosedRange<Int>) async throws -> Data {
        guard range.count <= Self.recordLimit else { throw Failure.malformed }
        var request = URLRequest(url: url)
        request.setValue("bytes=\(range.lowerBound)-\(range.upperBound)", forHTTPHeaderField: "Range")
        let data = try await load(request, limit: range.count) { http in
            guard http.statusCode == 206, let contentRange = http.value(forHTTPHeaderField: "Content-Range") else { return false }
            return contentRange.hasPrefix("bytes \(range.lowerBound)-\(range.upperBound)/")
        }
        guard data.count == range.count else { throw Failure.malformed }
        return data
    }

    private func load(_ request: URLRequest, limit: Int, accepts: (HTTPURLResponse) -> Bool) async throws -> Data {
        let stream: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (stream, response) = try await session.bytes(for: request)
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw Failure.transport
        }
        guard let http = response as? HTTPURLResponse else {
            stream.task.cancel()
            throw Failure.transport
        }
        if [403, 404, 416].contains(http.statusCode) {
            stream.task.cancel()
            throw Failure.missing
        }
        guard accepts(http), http.expectedContentLength <= Int64(limit) else {
            stream.task.cancel()
            throw Failure.malformed
        }
        var data = Data()
        data.reserveCapacity(max(Int(http.expectedContentLength), 0))
        do {
            for try await byte in stream {
                data.append(byte)
                if data.count > limit {
                    stream.task.cancel()
                    throw Failure.malformed
                }
            }
        } catch Failure.malformed {
            throw Failure.malformed
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            throw Failure.transport
        }
        return data
    }
}
