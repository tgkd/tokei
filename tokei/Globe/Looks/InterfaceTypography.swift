import SwiftUI

struct InterfaceTypography: Equatable {
    var design: Font.Design = .default
    var width: Font.Width = .standard
    var digitDesign: Font.Design = .default
    var digitWidth: Font.Width = .standard
    var displayWeight: Font.Weight = .semibold
    var titleWeight: Font.Weight = .semibold
    var bodyWeight: Font.Weight = .regular
    var captionWeight: Font.Weight = .regular
    var captionCase: Text.Case?
    var captionTracking: CGFloat = 0
    var captionItalic = false
    var symbolWeight: Font.Weight = .semibold
    var engraved = false

    func display(size: CGFloat) -> Font {
        Font.system(size: size, weight: displayWeight, design: digitDesign).width(digitWidth)
    }

    func period(size: CGFloat) -> Font {
        Font.system(size: size, weight: titleWeight, design: digitDesign).width(digitWidth)
    }

    func digits(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> Font {
        Font.system(style, design: digitDesign, weight: weight ?? displayWeight).width(digitWidth)
    }

    func title(_ style: Font.TextStyle) -> Font {
        Font.system(style, design: design, weight: titleWeight).width(width)
    }

    func body(_ style: Font.TextStyle) -> Font {
        Font.system(style, design: design, weight: bodyWeight).width(width)
    }

    func caption(_ style: Font.TextStyle) -> Font {
        let font = Font.system(style, design: design, weight: captionWeight).width(width)
        return captionItalic ? font.italic() : font
    }
}
