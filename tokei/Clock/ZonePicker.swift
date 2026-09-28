import SwiftUI

struct ZonePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.sceneAccent) private var accent
    @Environment(\.sceneStyle) private var style

    var title = "Add City"
    let date: Date
    var existing: Set<String> = []
    var selection: String?
    var onFollowDevice: (() -> Void)?
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
        let interface = style.interface
        NavigationStack {
            List {
                if let onFollowDevice, query.isEmpty {
                    Button {
                        onFollowDevice()
                        dismiss()
                    } label: {
                        deviceRow(interface: interface)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(interface.ink.opacity(0.12))
                    .accessibilityAddTraits(selection == nil ? .isSelected : [])
                }
                ForEach(results, id: \.self) { identifier in
                    let added = existing.contains(identifier)
                    Button {
                        onPick(identifier)
                        dismiss()
                    } label: {
                        row(identifier, added: added, interface: interface)
                    }
                    .buttonStyle(.plain)
                    .disabled(added)
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(interface.ink.opacity(0.12))
                    .accessibilityAddTraits(identifier == selection ? .isSelected : [])
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "City, region or GMT offset")
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(interface.typography.title(.headline))
                        .foregroundStyle(interface.ink)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(interface.typography.body(.body))
                }
            }
        }
        .tint(accent)
        .modifier(SheetBackground(color: interface.sheet))
    }

    private func row(_ identifier: String, added: Bool, interface: InterfaceLook) -> some View {
        let zone = TimeZone(identifier: identifier) ?? .current
        let region = Zone.regionName(for: identifier)
        let detail = [region, ZoneClock.gmtLabel(of: zone, at: date)].filter { !$0.isEmpty }.joined(separator: " · ")
        return rowLabel(Zone.cityName(for: identifier), detail: detail, zone: zone, isChecked: added || identifier == selection, interface: interface)
            .opacity(added ? 0.6 : 1)
    }

    private func deviceRow(interface: InterfaceLook) -> some View {
        let zone = TimeZone.current
        let detail = "\(Zone.cityName(for: zone.identifier)) · \(ZoneClock.gmtLabel(of: zone, at: date))"
        return rowLabel("Follow Device", detail: detail, zone: zone, isChecked: selection == nil, interface: interface)
    }

    private func rowLabel(_ title: String, detail: String, zone: TimeZone, isChecked: Bool, interface: InterfaceLook) -> some View {
        let typography = interface.typography
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(typography.title(.body))
                    .foregroundStyle(interface.ink)
                Text(detail)
                    .font(typography.caption(.footnote))
                    .textCase(typography.captionCase)
                    .tracking(typography.captionTracking)
                    .foregroundStyle(interface.secondaryInk)
            }
            Spacer(minLength: 8)
            if isChecked {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(accent)
            } else {
                DisplayTime(
                    date: date,
                    zone: zone,
                    font: typography.digits(.body, weight: typography.bodyWeight),
                    periodFont: typography.digits(.caption, weight: typography.titleWeight)
                )
                .foregroundStyle(interface.secondaryInk)
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
