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
        let baseTime = Date()
        let offsetMinutes = UserDefaults.shared.integer(forKey: "time_offset_minutes")
        return baseTime.addingTimeInterval(TimeInterval(offsetMinutes * 60))
    }
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        return formatter.string(from: currentTime)
    }
    
    var timeOffsetDisplay: String {
        let offsetMinutes = UserDefaults.shared.integer(forKey: "time_offset_minutes")
        if offsetMinutes == 0 {
            return ""
        } else if offsetMinutes > 0 {
            return "+\(offsetMinutes)min"
        } else {
            return "\(offsetMinutes)min"
        }
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

extension TimeZoneInfo {
    static let defaultTimeZones = [
        TimeZoneInfo(cityName: "London", timeZoneIdentifier: "Europe/London", weatherEmoji: "🌅"),
        TimeZoneInfo(cityName: "Yekaterinburg", timeZoneIdentifier: "Asia/Yekaterinburg", weatherEmoji: "☀️"),
        TimeZoneInfo(cityName: "Buenos Aires", timeZoneIdentifier: "America/Argentina/Buenos_Aires", weatherEmoji: "🌅"),
        TimeZoneInfo(cityName: "New York", timeZoneIdentifier: "America/New_York", weatherEmoji: "🌤️"),
        TimeZoneInfo(cityName: "Tokyo", timeZoneIdentifier: "Asia/Tokyo", weatherEmoji: "🌙"),
        TimeZoneInfo(cityName: "Sydney", timeZoneIdentifier: "Australia/Sydney", weatherEmoji: "🌞")
    ]
}