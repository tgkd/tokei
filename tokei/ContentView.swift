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
  @State private var timeOffsetMinutes: Double = 0
  @State private var isEditingSlider = false

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
        if timeZones.isEmpty {
          VStack {
            Text("World Clock")
              .font(.largeTitle)
              .fontWeight(.bold)
              .padding(.bottom, 20)

            Spacer()
            Text("No time zones added yet")
              .foregroundColor(.secondary)
            Spacer()
          }
        } else {
          VStack(alignment: .leading, spacing: 0) {
            Text("World Clock")
              .font(.largeTitle)
              .fontWeight(.bold)
              .padding(.horizontal, 20)
            List {
              ForEach(timeZones) { timeZone in
                TimeZoneRow(timeZone: timeZone) {
                  removeTimeZone(timeZone)
                }
                .draggable(timeZone)
              }
              .onDelete(perform: deleteTimeZones)
              .onMove(perform: moveTimeZones)
            }
            .dropDestination(for: TimeZoneInfo.self) { items, location in
              return handleDrop(items: items, location: location)
            }
          }
        }

        HStack {
          ZStack(alignment: .leading) {
            Slider(
              value: $timeOffsetMinutes, in: -1440...1440, step: 15,
              onEditingChanged: { editing in
                isEditingSlider = editing
              }
            )
            .onChange(of: timeOffsetMinutes) {
              updateTimeOffset(minutes: Int(timeOffsetMinutes))
            }

            if isEditingSlider {
              Text(timeOffsetText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.8))
                .cornerRadius(6)
                .offset(
                  x: thumbPosition,
                  y: -40
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isEditingSlider)
            }
          }
          Button(action: {
            resetTimeOffset()
          }) {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 20))
              .foregroundColor(.secondary)
              .opacity(timeOffsetMinutes == 0 ? 0.5 : 1.0)
          }
          .buttonStyle(PlainButtonStyle())
          .disabled(timeOffsetMinutes == 0)

          Spacer(minLength: 24)
          Button(action: {
            showingAddTimeZone = true
          }) {
            Image(systemName: "plus")
              .font(.system(size: 24, weight: .medium))
              .foregroundColor(.white)
              .frame(width: 50, height: 50)
              .background(Color.blue)
              .clipShape(Circle())
          }
        }
        .padding(.horizontal)
        .padding(.top)
      }
      .onAppear {
        loadTimeZones()
        loadTimeOffset()
      }
    }
    .sheet(isPresented: $showingAddTimeZone) {
      AddTimeZoneView(
        cityName: $newCityName,
        timeZoneIdentifier: $newTimeZoneIdentifier,
        onAdd: { city, identifier in
          addTimeZone(city: city, identifier: identifier)
          showingAddTimeZone = false
        },
        onCancel: {
          showingAddTimeZone = false
        }
      )
    }
  }

  var timeOffsetText: String {
    let hours = abs(Int(timeOffsetMinutes)) / 60
    let minutes = abs(Int(timeOffsetMinutes)) % 60
    let sign = timeOffsetMinutes >= 0 ? "+" : "-"

    return String(format: "%@%02d:%02d", sign, hours, minutes)
  }

  var thumbPosition: CGFloat {
    let sliderWidth: CGFloat = 200
    let progress = (timeOffsetMinutes - (-1440)) / (1440 - (-1440))
    return CGFloat(progress) * sliderWidth - 20
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
      let savedTimeZones = try? JSONDecoder().decode([TimeZoneInfo].self, from: data)
    else {
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

  private func addTimeZone(city: String, identifier: String) {
    let newTimeZone = TimeZoneInfo(
      cityName: city,
      timeZoneIdentifier: identifier
    )
    timeZones.append(newTimeZone)
    saveTimeZones()
  }

  private func removeTimeZone(_ timeZone: TimeZoneInfo) {
    timeZones.removeAll { $0.id == timeZone.id }
    saveTimeZones()
  }

  private func deleteTimeZones(at offsets: IndexSet) {
    timeZones.remove(atOffsets: offsets)
    saveTimeZones()
  }

  private func moveTimeZones(from source: IndexSet, to destination: Int) {
    timeZones.move(fromOffsets: source, toOffset: destination)
    saveTimeZones()
  }

  private func handleDrop(items: [TimeZoneInfo], location: CGPoint) -> Bool {
    return true
  }

  private func updateWidget() {
    WidgetCenter.shared.reloadTimelines(ofKind: "TokeiWidget")
  }
}

struct TimeZoneRow: View {
  let timeZone: TimeZoneInfo
  let onRemove: () -> Void

  var body: some View {
    HStack(spacing: 16) {
      VStack(alignment: .leading, spacing: 4) {
        Text(timeZone.cityName)
          .font(.headline)
          .fontWeight(.semibold)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 2) {
        Text(timeZone.formattedTime)
          .font(.system(.title2, design: .monospaced))
          .fontWeight(.bold)

        Text(timeZone.formattedDate)
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
      Button(role: .destructive, action: onRemove) {
        Image(systemName: "trash")
      }
    }
  }
}

struct AddTimeZoneView: View {
  @Binding var cityName: String
  @Binding var timeZoneIdentifier: String
  let onAdd: (String, String) -> Void
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
          onAdd(timeZone.cityName, timeZone.timeZoneIdentifier)
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
              .font(.system(size: 24, weight: .medium))
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
