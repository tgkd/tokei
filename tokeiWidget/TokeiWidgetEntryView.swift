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
        VStack(spacing: 6) {
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
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .scaleEffect(timeZone.dynamicTimeScale)
                                    .foregroundColor(timeZone.dynamicTimeColor)
                                
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
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.bold)
                                .scaleEffect(timeZone.dynamicTimeScale)
                                .foregroundColor(timeZone.dynamicTimeColor)
                            
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
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(Array(entry.timeZones.prefix(4))) { timeZone in
                    VStack(alignment: .center, spacing: 2) {
                        Text(timeZone.shortCityName)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .foregroundColor(.secondary)
                        
                        Text(timeZone.formattedTime)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .scaleEffect(timeZone.dynamicTimeScale)
                            .foregroundColor(timeZone.dynamicTimeColor)
                        
                        VStack(spacing: 0) {
                            Text(timeZone.timeOffset)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            Text("")
                                .font(.system(size: 8))
                                .frame(height: 10)
                        }
                        .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
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
                        .frame(minWidth: 52, minHeight: 24)
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
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
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
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.bold)
                                .scaleEffect(timeZone.dynamicTimeScale)
                                .foregroundColor(timeZone.dynamicTimeColor)
                            
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

struct TokeiCompactWidgetEntryView: View {
    var entry: Provider.Entry
    
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            CompactSmallWidget(entry: entry)
        case .systemMedium:
            CompactMediumWidget(entry: entry)
        default:
            CompactSmallWidget(entry: entry)
        }
    }
}

struct TokeiMinimalWidgetEntryView: View {
    var entry: Provider.Entry
    
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            MinimalSmallWidget(entry: entry)
        case .systemMedium:
            MinimalMediumWidget(entry: entry)
        default:
            MinimalSmallWidget(entry: entry)
        }
    }
}

struct CompactSmallWidget: View {
    let entry: TokeiEntry
    
    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(entry.timeZones.prefix(3))) { timeZone in
                HStack {
                    Text(timeZone.shortCityName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .frame(width: 30, alignment: .leading)
                    
                    Spacer()
                    
                    Text(timeZone.formattedTime)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.semibold)
                        .scaleEffect(timeZone.dynamicTimeScale)
                        .foregroundColor(timeZone.dynamicTimeColor)
                }
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Text(entry.formattedTimeOffset)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
    }
}

struct CompactMediumWidget: View {
    let entry: TokeiEntry
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(entry.timeZones.prefix(4))) { timeZone in
                VStack(spacing: 2) {
                    Text(timeZone.shortCityName)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(timeZone.formattedTime)
                        .font(.system(.caption, design: .monospaced))
                        .fontWeight(.semibold)
                        .scaleEffect(timeZone.dynamicTimeScale)
                        .foregroundColor(timeZone.dynamicTimeColor)
                    
                    Text(timeZone.timeOffset)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(8)
    }
}

struct MinimalSmallWidget: View {
    let entry: TokeiEntry
    
    var body: some View {
        if let timeZone = entry.timeZones.first {
            VStack(spacing: 4) {
                Text(timeZone.cityName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                Text(timeZone.formattedTime)
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.bold)
                    .scaleEffect(timeZone.dynamicTimeScale)
                    .foregroundColor(timeZone.dynamicTimeColor)
                
                Text(timeZone.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if entry.currentTimeOffsetMinutes != 0 {
                    Text(entry.formattedTimeOffset)
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                }
            }
            .padding(12)
        }
    }
}

struct MinimalMediumWidget: View {
    let entry: TokeiEntry
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(Array(entry.timeZones.prefix(2))) { timeZone in
                VStack(spacing: 4) {
                    Text(timeZone.cityName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text(timeZone.formattedTime)
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                        .scaleEffect(timeZone.dynamicTimeScale)
                        .foregroundColor(timeZone.dynamicTimeColor)
                    
                    Text(timeZone.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
    }
}
