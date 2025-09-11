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
