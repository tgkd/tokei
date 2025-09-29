import SwiftUI
import WidgetKit

struct TimeZoneListView: View {
    @Binding var timeZones: [TimeZoneInfo]
    @State private var showingAddTimeZone = false
    @State private var newCityName = ""
    @State private var newTimeZoneIdentifier = ""
    @State private var timeOffsetMinutes: Double = 0
    @State private var isEditingSlider = false
    @State private var showSlider = false
    @State private var showSliderContent = false

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    if timeZones.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 80))
                                .foregroundColor(.secondary)
                                .padding(.top, 60)

                            VStack(spacing: 8) {
                                Text("No Time Zones Added")
                                    .font(.title2)
                                    .fontWeight(.semibold)

                                Text("Add your first time zone to get started")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }

                            Button(action: {
                                showingAddTimeZone = true
                            }) {
                                HStack {
                                    Image(systemName: "plus")
                                    Text("Add Time Zone")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(25)
                            }
                            .padding(.top, 20)

                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
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

                VStack {
                    Spacer()
                    HStack {
                        HStack(spacing: 0) {
                            Button(action: {
                                if showSlider {
                                    withAnimation(.easeInOut(duration: 0.1)) {
                                        showSliderContent = false
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        withAnimation(.easeInOut(duration: 0.08)) {
                                            showSlider = false
                                        }
                                    }
                                } else {
                                    withAnimation(.easeInOut(duration: 0.08)) {
                                        showSlider = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                        withAnimation(.easeInOut(duration: 0.12)) {
                                            showSliderContent = true
                                        }
                                    }
                                }
                            }) {
                                if showSlider {
                                    Text(timeOffsetText)
                                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                                        .foregroundColor(.primary)
                                        .frame(width: 80, height: 44)
                                } else {
                                    Image(systemName: "clock")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.primary)
                                        .frame(width: 50, height: 44)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())

                            if showSlider {
                                HStack(spacing: 8) {
                                    if showSliderContent {
                                        Slider(
                                            value: $timeOffsetMinutes, in: -1440...1440, step: 15,
                                            onEditingChanged: { editing in
                                                isEditingSlider = editing
                                            }
                                        )
                                        .onChange(of: timeOffsetMinutes) {
                                            updateTimeOffset(minutes: Int(timeOffsetMinutes))
                                        }
                                        .frame(minWidth: 120)
                                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .leading)))

                                        Button(action: {
                                            resetTimeOffset()
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 18))
                                                .foregroundColor(.secondary)
                                                .opacity(timeOffsetMinutes == 0 ? 0.5 : 1.0)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                        .disabled(timeOffsetMinutes == 0)
                                        .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .trailing)))
                                    }
                                }
                                .padding(.trailing, 12)
                                .transition(
                                    .asymmetric(
                                        insertion: .move(edge: .leading).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)
                                    ))
                            }
                        }
                        .padding(.horizontal, showSlider ? 8 : 12)
                        .padding(.vertical, 8)
                        .background(.thickMaterial, in: showSlider ? AnyShape(RoundedRectangle(cornerRadius: 42)) : AnyShape(Circle()))
                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)

                        Spacer(minLength: 24)

                        if !timeZones.isEmpty {
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
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Time Zones")
            .onAppear {
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

    private func saveTimeZones() {
        if let data = try? JSONEncoder().encode(timeZones) {
            UserDefaults.shared.set(data, forKey: "saved_timezones")
        }
        updateWidget()
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
                    .scaleEffect(timeZone.dynamicTimeScale)
                    .foregroundColor(timeZone.dynamicTimeColor)

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

#Preview {
    TimeZoneListView(timeZones: .constant([]))
}