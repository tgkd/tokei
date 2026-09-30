import SwiftUI

struct TapeNeedle: View {
    @Environment(\.sceneStyle) private var style
    @Environment(\.sceneAccent) private var accent

    var body: some View {
        let tape = style.interface.tape
        let outline = tape.needleOutline ?? .clear
        switch tape.needle {
        case .capsule:
            Capsule()
                .fill(accent)
                .frame(width: 2.5)
                .padding(.vertical, 2)
        case .chunky:
            Capsule()
                .fill(accent)
                .overlay {
                    Capsule().strokeBorder(outline, lineWidth: 1.25)
                }
                .frame(width: 6)
        case .hairline:
            VStack(spacing: 0) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 1.25)
                Rectangle()
                    .fill(accent)
                    .frame(width: 5, height: 5)
                    .rotationEffect(.degrees(45))
                    .padding(.top, -3)
            }
            .padding(.bottom, 1)
        case .bar:
            Rectangle()
                .fill(accent)
                .overlay {
                    Rectangle().strokeBorder(outline, lineWidth: 1)
                }
                .frame(width: 4)
        case .pin:
            VStack(spacing: 0) {
                Rectangle()
                    .fill(accent)
                    .frame(width: 2)
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                    .padding(.top, -2)
            }
        case .pixel:
            PixelNeedle(color: accent)
                .background {
                    PixelNeedle(color: outline)
                        .offset(x: 2, y: 2)
                }
        }
    }
}

private struct PixelNeedle: View {
    let color: Color

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(width: 12, height: 2)
            Rectangle()
                .fill(color)
                .frame(width: 8, height: 2)
            Rectangle()
                .fill(color)
                .frame(width: 4)
            Rectangle()
                .fill(color)
                .frame(width: 8, height: 2)
            Rectangle()
                .fill(color)
                .frame(width: 12, height: 2)
        }
    }
}
