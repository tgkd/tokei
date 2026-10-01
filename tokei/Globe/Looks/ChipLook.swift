import SwiftUI

struct ChipLook: Equatable {
    struct Face: Hashable {
        var size: CGFloat
        var weight: Font.Weight
        var design: Font.Design = .default
        var width: Font.Width = .standard
        var monospacedDigits = false
        var italic = false
    }

    var name: Face
    var time: Face
    var detail: Face
    var uppercasedName = false
    var horizontalPadding: CGFloat = 9
    var verticalPadding: CGFloat = 5
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 1
    var corner: CGFloat
    var surface: SurfaceLook
    var selectedSurface: SurfaceLook?
    var nameColor: Color
    var timeColor: Color
    var detailColor: Color
    var shiftedTimeColor: Color?
    var selectedInk: Color?
    var flipsOnSelect = false
}
