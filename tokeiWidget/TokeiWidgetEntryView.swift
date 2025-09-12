import WidgetKit
import SwiftUI
import AppIntents

struct TokeiWidgetEntryView: View {
    var entry: Provider.Entry
    
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallTimeZoneWidget(entry: entry)
        case .systemMedium:
            MediumCompactTimeZoneWidget(entry: entry)
        case .systemLarge:
            LargeTimeZoneWidget(entry: entry)
        default:
            SmallTimeZoneWidget(entry: entry)
        }
    }
}

struct SmallTimeZoneWidget: View {
    let entry: TokeiEntry
    
    var body: some View {
        VStack(spacing: 2) {
            HStack {
                Spacer()
                Button(intent: RefreshTimeZonesIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            VStack(spacing: 4) {
                ForEach(Array(entry.timeZones.prefix(2))) { timeZone in
                    VStack(spacing: 1) {
                        HStack {
                            Text(timeZone.cityName)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            Spacer()
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(timeZone.formattedTime)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                
                                Text(timeZone.formattedDate)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text(timeZone.timeOffset)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            
            Spacer()
        }
        .padding(8)
    }
}

struct MediumTimeZoneWidget: View {
    let entry: TokeiEntry
    
    var body: some View {
        VStack(spacing: 4) {
            VStack(spacing: 4) {
                ForEach(Array(entry.timeZones.prefix(2))) { timeZone in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(timeZone.cityName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(timeZone.formattedTime)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(timeZone.timeOffset == "Now" ? .green : .primary)
                            
                            Text(timeZone.formattedDate)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(intent: {
                    let intent = AdjustTimeIntent()
                    intent.minutesToAdd = -30
                    return intent
                }()) {
                    Text("-30")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(minWidth: 36, minHeight: 28)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(intent: ResetTimeIntent()) {
                    Text(entry.formattedTimeOffset)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(minWidth: 52, minHeight: 28)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(intent: {
                    let intent = AdjustTimeIntent()
                    intent.minutesToAdd = 30
                    return intent
                }()) {
                    Text("+30")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(minWidth: 36, minHeight: 28)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(intent: RefreshTimeZonesIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

struct MediumCompactTimeZoneWidget: View {
    let entry: TokeiEntry
    
    private func dayShiftText(for timeZone: TimeZoneInfo) -> String {
        let currentDate = Date()
        let offsetMinutes = UserDefaults.shared.integer(forKey: "time_offset_minutes")
        let adjustedTime = currentDate.addingTimeInterval(TimeInterval(offsetMinutes * 60))
        
        // Get current day in local timezone
        let localCalendar = Calendar.current
        let localDay = localCalendar.component(.day, from: adjustedTime)
        
        // Get day in target timezone
        var targetCalendar = Calendar.current
        targetCalendar.timeZone = timeZone.timeZone
        let targetDay = targetCalendar.component(.day, from: adjustedTime)
        
        let dayDiff = targetDay - localDay
        
        if dayDiff > 0 {
            return "+1day"
        } else if dayDiff < 0 {
            return "-1day"
        } else {
            return ""
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 2) {
                ForEach(Array(entry.timeZones.prefix(4))) { timeZone in
                    VStack(spacing: 1) {
                        Text(timeZone.shortCityName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                        
                        Text(timeZone.formattedTime)
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                            .foregroundColor(timeZone.timeOffset == "Now" ? .green : .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        
                        VStack(spacing: 0) {
                            Text(timeZone.timeOffset)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            Text(dayShiftText(for: timeZone))
                                .font(.system(size: 8))
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                        }
                        .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    
                    if timeZone.id != entry.timeZones.prefix(4).last?.id {
                        Divider()
                            .frame(height: 28)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 6) {
                Button(intent: {
                    let intent = AdjustTimeIntent()
                    intent.minutesToAdd = -30
                    return intent
                }()) {
                    Text("-30")
                        .font(.system(size: 11))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(minWidth: 32, minHeight: 24)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(intent: ResetTimeIntent()) {
                    Text(entry.formattedTimeOffset)
                        .font(.system(size: 11))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(minWidth: 40, minHeight: 24)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(intent: {
                    let intent = AdjustTimeIntent()
                    intent.minutesToAdd = 30
                    return intent
                }()) {
                    Text("+30")
                        .font(.system(size: 11))
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(minWidth: 32, minHeight: 24)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(intent: RefreshTimeZonesIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

struct LargeTimeZoneWidget: View {
    let entry: TokeiEntry
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("World Clock")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.bottom, 12)
            
            VStack(spacing: 8) {
                ForEach(Array(entry.timeZones.prefix(5))) { timeZone in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(timeZone.cityName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(timeZone.formattedTime)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(timeZone.timeOffset == "Now" ? .green : .primary)
                            
                            Text(timeZone.formattedDate)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(intent: {
                    let intent = AdjustTimeIntent()
                    intent.minutesToAdd = -30
                    return intent
                }()) {
                    Text("-30")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(minWidth: 36, minHeight: 28)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(intent: ResetTimeIntent()) {
                    Text(entry.formattedTimeOffset)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(minWidth: 52, minHeight: 28)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(intent: {
                    let intent = AdjustTimeIntent()
                    intent.minutesToAdd = 30
                    return intent
                }()) {
                    Text("+30")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .frame(minWidth: 36, minHeight: 28)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                Button(intent: RefreshTimeZonesIntent()) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(12)
    }
}
