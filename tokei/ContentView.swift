//
//  ContentView.swift
//  tokei
//
//  Created by P on 9/9/25.
//

import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var timeZones: [TimeZoneInfo] = []
    @State private var showingAddTimeZone = false
    @State private var newCityName = ""
    @State private var newTimeZoneIdentifier = ""
    @State private var newWeatherEmoji = "🌍"
    @State private var timeOffsetMinutes: Double = 0
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("Time Adjustment")
                                .font(.headline)
                            Spacer()
                            if timeOffsetMinutes != 0 {
                                Button("Reset") {
                                    resetTimeOffset()
                                }
                                .buttonStyle(.bordered)
                                .font(.caption)
                            }
                        }
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("-24h")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(timeOffsetText)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(timeOffsetMinutes == 0 ? .secondary : .blue)
                                Spacer()
                                Text("+24h")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Slider(value: $timeOffsetMinutes, in: -1440...1440, step: 15) {
                                Text("Time Offset")
                            }
                            .onChange(of: timeOffsetMinutes) { newValue in
                                updateTimeOffset(minutes: Int(newValue))
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    if timeZones.isEmpty {
                        Text("No time zones added yet")
                            .foregroundColor(.secondary)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(timeZones) { timeZone in
                                    TimeZoneRow(timeZone: timeZone) {
                                        removeTimeZone(timeZone)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .onAppear {
                    loadTimeZones()
                    loadTimeOffset()
                }
                .navigationTitle("")
                .navigationBarHidden(true)
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingAddTimeZone = true
                        }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                                .frame(width: 48, height: 48)
                                .background(Color.blue)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddTimeZone) {
            AddTimeZoneView(
                cityName: $newCityName,
                timeZoneIdentifier: $newTimeZoneIdentifier,
                weatherEmoji: $newWeatherEmoji,
                onAdd: { city, identifier, emoji in
                    addTimeZone(city: city, identifier: identifier, emoji: emoji)
                    showingAddTimeZone = false
                },
                onCancel: {
                    showingAddTimeZone = false
                }
            )
        }
    }
    
    var timeOffsetText: String {
        if timeOffsetMinutes == 0 {
            return "No offset"
        } else {
            let hours = abs(Int(timeOffsetMinutes)) / 60
            let minutes = abs(Int(timeOffsetMinutes)) % 60
            let sign = timeOffsetMinutes >= 0 ? "+" : "-"
            
            if minutes == 0 {
                return "\(sign)\(hours)h"
            } else {
                return "\(sign)\(hours)h \(minutes)m"
            }
        }
    }
    
    private func loadTimeOffset() {
        timeOffsetMinutes = Double(UserDefaults.shared.integer(forKey: "time_offset_minutes"))
    }
    
    private func updateTimeOffset(minutes: Int) {
        UserDefaults.shared.set(minutes, forKey: "time_offset_minutes")
        updateWidget()
    }
    
    private func resetTimeOffset() {
        timeOffsetMinutes = 0
        updateTimeOffset(minutes: 0)
    }
    
    private func loadTimeZones() {
        guard let data = UserDefaults.shared.data(forKey: "saved_timezones"),
              let savedTimeZones = try? JSONDecoder().decode([TimeZoneInfo].self, from: data) else {
            timeZones = Array(TimeZoneInfo.defaultTimeZones.prefix(3))
            saveTimeZones()
            return
        }
        timeZones = savedTimeZones
    }
    
    private func saveTimeZones() {
        if let data = try? JSONEncoder().encode(timeZones) {
            UserDefaults.shared.set(data, forKey: "saved_timezones")
        }
        updateWidget()
    }
    
    private func addTimeZone(city: String, identifier: String, emoji: String) {
        let newTimeZone = TimeZoneInfo(
            cityName: city,
            timeZoneIdentifier: identifier,
            weatherEmoji: emoji
        )
        timeZones.append(newTimeZone)
        saveTimeZones()
    }
    
    private func removeTimeZone(_ timeZone: TimeZoneInfo) {
        timeZones.removeAll { $0.id == timeZone.id }
        saveTimeZones()
    }
    
    private func updateWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "TokeiWidget")
    }
}

struct TimeZoneRow: View {
    let timeZone: TimeZoneInfo
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(timeZone.cityName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(timeZone.relativeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeZone.formattedTime)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(timeZone.timeOffset == "Now" ? .green : .primary)
                
                if !timeZone.formattedDateForDifference.isEmpty {
                    Text(timeZone.formattedDateForDifference)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
    }
}

struct AddTimeZoneView: View {
    @Binding var cityName: String
    @Binding var timeZoneIdentifier: String
    @Binding var weatherEmoji: String
    let onAdd: (String, String, String) -> Void
    let onCancel: () -> Void
    
    @State private var searchText = ""
    
    var filteredTimeZones: [SearchableTimeZone] {
        if searchText.isEmpty {
            return TimeZoneInfo.allAvailableTimeZones
        } else {
            return TimeZoneInfo.allAvailableTimeZones.filter { timeZone in
                timeZone.searchableText.contains(searchText.lowercased())
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List(filteredTimeZones, id: \.timeZoneIdentifier) { timeZone in
                Button(action: {
                    onAdd(timeZone.cityName, timeZone.timeZoneIdentifier, "")
                }) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(timeZone.displayName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Text(timeZone.gmtOffset)
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                                
                                Text(timeZone.timeZoneIdentifier)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .searchable(text: $searchText, prompt: "Search by city, country, or GMT offset")
            .navigationTitle("Add Time Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}


extension UserDefaults {
    static let shared = UserDefaults(suiteName: "group.tokei.widget")!
}

#Preview {
    ContentView()
}
