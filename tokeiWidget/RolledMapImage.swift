import SwiftUI
import WidgetKit

struct RolledMapImage: View {
    let name: String
    let centerLongitude: Double
    let size: CGSize

    var body: some View {
        let shift = -CGFloat(centerLongitude / 360) * size.width
        HStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { _ in
                Image(name)
                    .resizable()
                    .widgetAccentedRenderingMode(.desaturated)
                    .frame(width: size.width, height: size.height)
            }
        }
        .offset(x: shift - size.width)
        .frame(width: size.width, height: size.height, alignment: .leading)
        .clipped()
    }
}
