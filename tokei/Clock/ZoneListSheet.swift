import SwiftUI

struct ZoneListSheet: View {
    @Environment(ClockStore.self) private var store
    @Environment(\.sceneAccent) private var accent
    @Environment(\.sceneStyle) private var style

    let date: Date
    let isShifted: Bool

    @State private var showsPicker = false

    var body: some View {
        let interface = style.interface
        NavigationStack {
            Group {
                if store.zones.isEmpty {
                    ContentUnavailableView {
                        Label("No Cities", systemImage: "globe.europe.africa")
                            .font(interface.typography.title(.title2))
                            .foregroundStyle(interface.ink)
                    } description: {
                        Text("Add a city to see its time on the globe.")
                            .font(interface.typography.body(.body))
                            .foregroundStyle(interface.secondaryInk)
                    } actions: {
                        Button("Add City") {
                            showsPicker = true
                        }
                        .font(interface.typography.title(.body))
                        .buttonStyle(.borderedProminent)
                        .tint(accent)
                        .foregroundStyle(interface.onAccent)
                    }
                } else {
                    List {
                        ForEach(store.zones) { zone in
                            let isSelected = zone.id == store.selection
                            Button {
                                store.focus(on: zone)
                            } label: {
                                ZoneRow(zone: zone, date: date, isShifted: isShifted, isSelected: isSelected)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(isSelected ? interface.ink.opacity(0.07) : Color.clear)
                            .listRowSeparatorTint(interface.ink.opacity(0.12))
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                ToolbarItem(placement: .principal) {
                    Text("Cities")
                        .font(interface.typography.title(.headline))
                        .foregroundStyle(interface.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .topBarLeading) {
                    if !store.zones.isEmpty {
                        EditButton()
                            .font(interface.typography.body(.body))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsPicker = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(interface.typography.symbolWeight)
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
        .tint(accent)
        .modifier(SheetBackground(color: interface.sheet))
    }
}
