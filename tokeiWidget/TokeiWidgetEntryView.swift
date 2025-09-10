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
            MediumTimeZoneWidget(entry: entry)
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
                                
                                if !timeZone.formattedDateForDifference.isEmpty {
                                    Text(timeZone.formattedDateForDifference)
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                }
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
        VStack(spacing: 8) {
            VStack(spacing: 6) {
                ForEach(Array(entry.timeZones.prefix(2))) { timeZone in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(timeZone.cityName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                            
                            Text(timeZone.relativeDescription)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(timeZone.formattedTime)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(timeZone.timeOffset == "Now" ? .green : .primary)
                            
                            if !timeZone.formattedDateForDifference.isEmpty {
                                Text(timeZone.formattedDateForDifference)
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            
            Spacer()
                        HStack(spacing: 4) {
                Button(intent: {
                    let intent = AdjustTimeIntent()
                    intent.minutesToAdd = -30
                    return intent
                }()) {
                    Text("-30 min")
                        .font(.caption2)
                        .frame(height: 24)
                        .padding(.horizontal, 8)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(intent: ResetTimeIntent()) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .frame(height: 24)
                        .padding(.horizontal, 8)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(intent: {
                    let intent = AdjustTimeIntent()
                    intent.minutesToAdd = 30
                    return intent
                }()) {
                    Text("+30 min")
                        .font(.caption2)
                        .frame(height: 24)
                        .padding(.horizontal, 8)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
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
                            
                            Text(timeZone.relativeDescription)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(timeZone.formattedTime)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(timeZone.timeOffset == "Now" ? .green : .primary)
                            
                            if !timeZone.formattedDateForDifference.isEmpty {
                                Text(timeZone.formattedDateForDifference)
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Button(intent: {
                    let intent = AdjustTimeIntent()
                    intent.minutesToAdd = -30
                    return intent
                }()) {
                    Text("-30 min")
                        .font(.caption2)
                        .frame(height: 24)
                        .padding(.horizontal, 8)
                        .background(Color.red.opacity(0.1))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(intent: ResetTimeIntent()) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .frame(height: 24)
                        .padding(.horizontal, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
                .buttonStyle(PlainButtonStyle())
                
                Button(intent: {
                    let intent = AdjustTimeIntent()
                    intent.minutesToAdd = 15
                    return intent
                }()) {
                    Text("+15 min")
                        .font(.caption2)
                        .frame(height: 24)
                        .padding(.horizontal, 8)
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(4)
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
