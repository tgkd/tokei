import SwiftUI
import WidgetKit

struct DayNightMapView: View {
    @Environment(\.widgetLook) private var look

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
                map(center: center, size: mapSize)
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

    @ViewBuilder
    private func map(center: Double, size: CGSize) -> some View {
        switch look.map {
        case .photo:
            ZStack {
                RolledMapImage(image: Image("MapDay"), centerLongitude: center, size: size)
                if let mask = entry.nightMask {
                    RolledMapImage(image: Image("MapNight"), centerLongitude: center, size: size)
                        .mask {
                            maskImage(mask, size: size, pixelated: false)
                        }
                }
            }
        case let .flat(ocean, land, coast, night, _):
            if let pixelMap = entry.pixelMap {
                ZStack {
                    Image(decorative: pixelMap.surface, scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: size.width, height: size.height)
                    if let mask = pixelMap.night {
                        Rectangle()
                            .fill(night)
                            .mask {
                                maskImage(mask, size: size, pixelated: true)
                            }
                    }
                }
            } else {
                ZStack {
                    Rectangle()
                        .fill(ocean)
                    RolledMapImage(image: Image("MapLand").renderingMode(.template), centerLongitude: center, size: size)
                        .foregroundStyle(land)
                    if let coast {
                        RolledMapImage(image: Image("MapCoast").renderingMode(.template), centerLongitude: center, size: size)
                            .foregroundStyle(coast)
                    }
                    if let mask = entry.nightMask {
                        Rectangle()
                            .fill(night)
                            .mask {
                                maskImage(mask, size: size, pixelated: false)
                            }
                    }
                }
            }
        }
    }

    private func maskImage(_ mask: CGImage, size: CGSize, pixelated: Bool) -> some View {
        Image(decorative: mask, scale: 1)
            .resizable()
            .interpolation(pixelated ? .none : .medium)
            .frame(width: size.width, height: size.height)
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
