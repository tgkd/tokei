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
        
        let dayDiff = dayDifference
        
        if diffSeconds == 0 {
            switch dayDiff {
            case 0:
                return "Same time"
            case 1:
                return "Tomorrow, same time"
            case -1:
                return "Yesterday, same time"
            default:
                return dayDiff > 0 ? "\(dayDiff) days ahead, same time" : "\(abs(dayDiff)) days behind, same time"
            }
        } else if diffSeconds > 0 {
            switch dayDiff {
            case 0:
                return "Today, \(diffHours)h ahead"
            case 1:
                return "Tomorrow, \(diffHours)h ahead"
            case -1:
                return "Yesterday, \(diffHours)h ahead"
            default:
                return dayDiff > 0 ? "\(dayDiff) days ahead, \(diffHours)h" : "\(abs(dayDiff)) days behind, \(diffHours)h ahead"
            }
        } else {
            switch dayDiff {
            case 0:
                return "Today, \(diffHours)h behind"
            case 1:
                return "Tomorrow, \(diffHours)h behind"
            case -1:
                return "Yesterday, \(diffHours)h behind"
            default:
                return dayDiff > 0 ? "\(dayDiff) days ahead, \(diffHours)h behind" : "\(abs(dayDiff)) days behind, \(diffHours)h"
            }
        }
    }
    
    var dayDifference: Int {
        // Create calendars for both timezones
        var localCalendar = Calendar.current
        localCalendar.timeZone = TimeZone.current
        
        var targetCalendar = Calendar.current
        targetCalendar.timeZone = timeZone
        
        // Use the adjusted time that includes the offset
        let adjustedTime = currentTime
        
        // Get the current day in local timezone (using current time, not adjusted)
        let localDay = localCalendar.dateComponents([.year, .month, .day], from: Date())
        let localDayDate = localCalendar.date(from: localDay)!
        
        // Get the corresponding day in target timezone using adjusted time
        let targetDay = targetCalendar.dateComponents([.year, .month, .day], from: adjustedTime)
        let targetDayDate = targetCalendar.date(from: targetDay)!
        
        // Convert both dates to the same timezone (UTC) to properly compare days
        let utcCalendar = Calendar(identifier: .gregorian)
        let localDayUTC = utcCalendar.startOfDay(for: localDayDate)
        let targetDayUTC = utcCalendar.startOfDay(for: targetDayDate)
        
        // Calculate difference in days
        let daysDiff = utcCalendar.dateComponents([.day], from: localDayUTC, to: targetDayUTC).day ?? 0
        
        return daysDiff
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "dd.MM"
        return formatter.string(from: currentTime)
    }
    
    var formattedDateForDifference: String {
        guard dayDifference != 0 else { return "" }
        
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.dateFormat = "dd.MM"
        return "(\(formatter.string(from: currentTime)))"
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