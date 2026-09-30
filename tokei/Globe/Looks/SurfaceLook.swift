import SwiftUI

enum SurfaceLook: Equatable {
    case glass(tint: Color?, clear: Bool, edge: Color?)
    case solid(fill: Color, edge: Color?)
    case raised(fill: Color, base: Color, depth: CGFloat, edge: Color?)
    case metal(fill: Color, highlight: Color, shade: Color, brushed: Bool)
    case paper(fill: Color, edge: Color, shadow: Color)
    case pixel(fill: Color, edge: Color, shadow: Color, depth: CGFloat)

    var depth: CGFloat {
        switch self {
        case let .raised(_, _, depth, _): depth
        case let .pixel(_, _, _, depth): depth
        default: 0
        }
    }
}
