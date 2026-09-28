import SwiftUI

struct BeadLook: Equatable {
    var body: Color
    var shade: Color
    var highlight: Color
    var outline: Color
    var outlineWidth: CGFloat = 1
    var shadow: Color?
    var halo: Color?
}
