import Foundation

struct TimeZoneInfo: Identifiable, Codable {
    let id: UUID
    let cityName: String
    let timeZoneIdentifier: String
    let weatherEmoji: String
    
    init(cityName: String, timeZoneIdentifier: String, weatherEmoji: String) {
        self.id = UUID()
        self.cityName = cityName
        self.timeZoneIdentifier = timeZoneIdentifier
        self.weatherEmoji = weatherEmoji
    }
    
    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
    }
    
    var currentTime: Date {
        Date()
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        return formatter.string(from: currentTime)
    }
    
    var timeOffset: String {
        let currentTimeZone = TimeZone.current
        let targetTimeZone = timeZone
        
        let currentOffset = currentTimeZone.secondsFromGMT()
        let targetOffset = targetTimeZone.secondsFromGMT()
        
        let diffSeconds = targetOffset - currentOffset
        let diffHours = diffSeconds / 3600
        
        if diffHours == 0 {
            return "Now"
        } else if diffHours > 0 {
            return "+\(diffHours)h"
        } else {
            return "\(diffHours)h"
        }
    }
    
    var relativeDescription: String {
        let currentTimeZone = TimeZone.current
        let targetTimeZone = timeZone
        
        let currentOffset = currentTimeZone.secondsFromGMT()
        let targetOffset = targetTimeZone.secondsFromGMT()
        
        let diffSeconds = targetOffset - currentOffset
        let diffHours = abs(diffSeconds / 3600)
        
        if diffSeconds == 0 {
            return "Same time"
        } else if diffSeconds > 0 {
            return "Today, \(diffHours) hours ahead"
        } else {
            return "Today, \(diffHours) hours behind"
        }
    }
}

struct SearchableTimeZone {
    let timeZoneIdentifier: String
    
    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
    }
    
    var cityName: String {
        let components = timeZoneIdentifier.components(separatedBy: "/")
        return components.last?.replacingOccurrences(of: "_", with: " ") ?? timeZoneIdentifier
    }
    
    var regionName: String {
        let components = timeZoneIdentifier.components(separatedBy: "/")
        if components.count > 1 {
            return components[0].replacingOccurrences(of: "_", with: " ")
        }
        return ""
    }
    
    var gmtOffset: String {
        let offset = timeZone.secondsFromGMT() / 3600
        if offset == 0 {
            return "GMT"
        } else if offset > 0 {
            return "GMT+\(offset)"
        } else {
            return "GMT\(offset)"
        }
    }
    
    var displayName: String {
        if !regionName.isEmpty {
            return "\(cityName) (\(regionName))"
        }
        return cityName
    }
    
    var searchableText: String {
        "\(cityName.lowercased()) \(regionName.lowercased()) \(gmtOffset.lowercased()) \(timeZoneIdentifier.lowercased())"
    }
    
    func toTimeZoneInfo() -> TimeZoneInfo {
        TimeZoneInfo(cityName: cityName, timeZoneIdentifier: timeZoneIdentifier, weatherEmoji: "")
    }
}

extension TimeZoneInfo {
    static let defaultTimeZones = [
        TimeZoneInfo(cityName: "Yekaterinburg", timeZoneIdentifier: "Asia/Yekaterinburg", weatherEmoji: "☀️"),
        TimeZoneInfo(cityName: "London", timeZoneIdentifier: "Europe/London", weatherEmoji: "🌅"),
        TimeZoneInfo(cityName: "Buenos Aires", timeZoneIdentifier: "America/Argentina/Buenos_Aires", weatherEmoji: "🌅"),
        TimeZoneInfo(cityName: "Tokyo", timeZoneIdentifier: "Asia/Tokyo", weatherEmoji: "🌙"),
    ]
    
    static var allAvailableTimeZones: [SearchableTimeZone] {
        return TimeZone.knownTimeZoneIdentifiers
            .sorted()
            .compactMap { identifier in
                guard !identifier.hasPrefix("GMT") else { return nil }
                return SearchableTimeZone(timeZoneIdentifier: identifier)
            }
    }
}