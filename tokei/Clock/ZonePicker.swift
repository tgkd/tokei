import SwiftUI

struct ZonePicker: View {
    @Environment(\.dismiss) private var dismiss

    let date: Date
    let existing: Set<String>
    let onPick: (String) -> Void

    @State private var query = ""

    private static let identifiers: [String] = TimeZone.knownTimeZoneIdentifiers
        .filter { $0.contains("/") && !$0.hasPrefix("Etc/") && !$0.hasPrefix("GMT") }
        .sorted { Zone.cityName(for: $0) < Zone.cityName(for: $1) }

    private var results: [String] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return Self.identifiers }
        return Self.identifiers.filter { identifier in
            guard let zone = TimeZone(identifier: identifier) else { return false }
            let haystack = [
                identifier,
                Zone.cityName(for: identifier),
                ZoneClock.gmtLabel(of: zone, at: date),
                zone.abbreviation(for: date) ?? "",
            ].joined(separator: " ").lowercased()
            return haystack.contains(needle)
        }
    }

    var body: some View {
        NavigationStack {
            List(results, id: \.self) { identifier in
                let added = existing.contains(identifier)
                Button {
                    onPick(identifier)
                    dismiss()
                } label: {
                    row(identifier, added: added)
                }
                .buttonStyle(.plain)
                .disabled(added)
            }
            .listStyle(.plain)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "City, region or GMT offset")
            .navigationTitle("Add City")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func row(_ identifier: String, added: Bool) -> some View {
        let zone = TimeZone(identifier: identifier) ?? .current
        let region = Zone.regionName(for: identifier)
        let detail = [region, ZoneClock.gmtLabel(of: zone, at: date)].filter { !$0.isEmpty }.joined(separator: " · ")
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Zone.cityName(for: identifier))
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if added {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.sunlight)
            } else {
                Text(ZoneClock.time(date, in: zone))
                    .font(.body)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .opacity(added ? 0.6 : 1)
    }
}
