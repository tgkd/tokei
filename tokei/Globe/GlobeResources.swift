import Foundation

struct GlobeResources: Sendable {
    let directory: URL?

    static let main = GlobeResources(directory: nil)

    func url(_ name: String, _ fileExtension: String) -> URL? {
        if let directory {
            return directory.appendingPathComponent(name).appendingPathExtension(fileExtension)
        }
        return Bundle.main.url(forResource: name, withExtension: fileExtension)
    }
}
