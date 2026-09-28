import SwiftUI
import WidgetKit

struct DayNightMapView: View {
    let entry: ClockEntry
    var labelInsets = EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
    var reservedCorner: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let mapSize = CGSize(width: width, height: width / 2)
            let top = (proxy.size.height - mapSize.height) / 2
            let center = ClockEntry.mapCenterLongitude(for: entry.homeZone)
            ZStack(alignment: .topLeading) {
                ZStack {
                    RolledMapImage(name: "MapDay", centerLongitude: center, size: mapSize)
                    if let mask = entry.nightMask {
                        RolledMapImage(name: "MapNight", centerLongitude: center, size: mapSize)
                            .mask {
                                Image(decorative: mask, scale: 1)
                                    .resizable()
                                    .frame(width: mapSize.width, height: mapSize.height)
                            }
                    }
                }
                .frame(width: mapSize.width, height: mapSize.height)
                .offset(y: top)

                MapMarkers(
                    entry: entry,
                    centerLongitude: center,
                    mapSize: mapSize,
                    mapTop: top,
                    bounds: CGRect(origin: .zero, size: proxy.size).inset(by: labelInsets),
                    obstacles: reservedCorner == .zero ? [] : [
                        CGRect(
                            x: proxy.size.width - reservedCorner.width,
                            y: proxy.size.height - reservedCorner.height,
                            width: reservedCorner.width,
                            height: reservedCorner.height
                        ),
                    ]
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
    }
}

private extension CGRect {
    func inset(by insets: EdgeInsets) -> CGRect {
        CGRect(
            x: minX + insets.leading,
            y: minY + insets.top,
            width: width - insets.leading - insets.trailing,
            height: height - insets.top - insets.bottom
        )
    }
}
