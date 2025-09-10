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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "clock.fill")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                
                Text("Tokei World Clock")
                    .font(.title)
                    .fontWeight(.bold)
                
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
                
                Button("Add Time Zone") {
                    showingAddTimeZone = true
                }
                .buttonStyle(.borderedProminent)
                .font(.headline)
                
                Button("Update Widget") {
                    updateWidget()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .onAppear {
                loadTimeZones()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
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
            
            Text(timeZone.formattedTime)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(timeZone.timeOffset == "Now" ? .green : .primary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
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
