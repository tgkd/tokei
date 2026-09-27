import SwiftUI

struct ZoneListSheet: View {
    @Environment(ClockStore.self) private var store

    let date: Date
    let isShifted: Bool

    @State private var showsPicker = false

    var body: some View {
        NavigationStack {
            Group {
                if store.zones.isEmpty {
                    ContentUnavailableView {
                        Label("No Cities", systemImage: "globe.europe.africa")
                    } description: {
                        Text("Add a city to see its time on the globe.")
                    } actions: {
                        Button("Add City") {
                            showsPicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.sunlight)
                        .foregroundStyle(.black)
                    }
                } else {
                    List {
                        ForEach(store.zones) { zone in
                            Button {
                                store.focus(on: zone)
                            } label: {
                                ZoneRow(zone: zone, date: date, isShifted: isShifted, isSelected: zone.id == store.selection)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                        }
                        .onDelete { offsets in
                            store.remove(atOffsets: offsets)
                        }
                        .onMove { source, destination in
                            store.move(fromOffsets: source, toOffset: destination)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Cities")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.zones.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsPicker = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add City")
                }
            }
            .sheet(isPresented: $showsPicker) {
                ZonePicker(date: date, existing: Set(store.zones.map(\.timeZoneIdentifier))) { identifier in
                    store.add(identifier: identifier)
                }
            }
        }
    }
}
