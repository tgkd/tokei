import SwiftUI

struct TapeLook: Equatable {
    enum Needle: Equatable {
        case capsule
        case chunky
        case hairline
        case bar
        case pin
        case pixel
    }

    var tick: Color
    var label: Color
    var labelWeight: Font.Weight = .medium
    var labelDesign: Font.Design = .default
    var hourWidth: CGFloat = 1.5
    var quarterWidth: CGFloat = 1
    var squareCaps = false
    var needle: Needle
    var needleOutline: Color?
}
