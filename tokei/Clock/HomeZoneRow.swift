import SwiftUI

struct HomeZoneRow: View {
    @Environment(\.sceneStyle) private var style

    let zone: TimeZone
    let followsDevice: Bool

    var body: some View {
        let interface = style.interface
        let typography = interface.typography
        HStack(spacing: 14) {
            Image(systemName: "location.fill")
                .foregroundStyle(interface.secondaryInk)
                .font(.system(size: 17, weight: typography.symbolWeight))
                .frame(width: 30)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(Zone.cityName(for: zone.identifier))
                    .font(typography.title(.headline))
                    .foregroundStyle(interface.ink)
                Text(followsDevice ? "My time zone · Follows device" : "My time zone")
                    .font(typography.caption(.subheadline))
                    .tracking(typography.captionTracking)
                    .foregroundStyle(interface.secondaryInk)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: typography.symbolWeight))
                .foregroundStyle(interface.secondaryInk)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}
