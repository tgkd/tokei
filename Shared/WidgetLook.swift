import SwiftUI

struct WidgetLook: Codable, Equatable {
    enum Design: String, Codable {
        case standard
        case serif
        case rounded
        case monospaced
    }

    enum Weight: String, Codable {
        case ultraLight
        case thin
        case light
        case regular
        case medium
        case semibold
        case bold
        case heavy
        case black
    }

    struct Face: Codable, Equatable {
        var design: Design = .standard
        var width: CGFloat = 0
        var weight: Weight
        var italic = false
    }

    struct Typography: Codable, Equatable {
        var title: Face
        var digits: Face
        var caption: Face
        var uppercasedCaptions: Bool
        var captionTracking: CGFloat
        var symbolWeight: Weight
        var labelName: Face
        var labelTime: Face
        var uppercasedLabelNames: Bool
    }

    struct Surface: Codable, Equatable {
        var fill: Color.Resolved
        var edge: Color.Resolved?
        var edgeWidth: CGFloat = 0.75
        var base: Color.Resolved?
        var offset: CGSize = .zero
    }

    struct Label: Codable, Equatable {
        var surface: Surface
        var corner: CGFloat
        var nameColor: Color.Resolved
        var timeColor: Color.Resolved
        var shiftedTimeColor: Color.Resolved
    }

    struct Dot: Codable, Equatable {
        var fill: Color.Resolved
        var outline: Color.Resolved
        var outlineWidth: CGFloat
    }

    enum Map: Codable, Equatable {
        case photo
        case flat(ocean: Color.Resolved, land: Color.Resolved, coast: Color.Resolved?, night: Color.Resolved, pixelSize: CGFloat?)
    }

    var typography: Typography
    var background: Color.Resolved
    var ink: Color.Resolved
    var secondaryInk: Color.Resolved
    var accent: Color.Resolved
    var label: Label
    var dot: Dot
    var control: Surface
    var controlInk: Color.Resolved
    var controlAccent: Color.Resolved
    var map: Map

    var neutral: WidgetLook {
        var look = Self.standard
        look.typography = typography
        return look
    }

    static let standard = WidgetLook(
        typography: Typography(
            title: Face(weight: .semibold),
            digits: Face(design: .rounded, weight: .semibold),
            caption: Face(weight: .medium),
            uppercasedCaptions: false,
            captionTracking: 0,
            symbolWeight: .regular,
            labelName: Face(weight: .semibold),
            labelTime: Face(weight: .semibold),
            uppercasedLabelNames: false
        ),
        background: Color.space.resolved,
        ink: Color.white.resolved,
        secondaryInk: Color.white.opacity(0.65).resolved,
        accent: Color.sunlight.resolved,
        label: Label(
            surface: Surface(fill: Color.black.opacity(0.55).resolved),
            corner: 12,
            nameColor: Color.white.opacity(0.8).resolved,
            timeColor: Color.white.resolved,
            shiftedTimeColor: Color.sunlight.resolved
        ),
        dot: Dot(fill: Color.white.resolved, outline: Color.black.opacity(0.55).resolved, outlineWidth: 0.75),
        control: Surface(fill: Color.black.opacity(0.5).resolved, edge: Color.white.opacity(0.12).resolved, edgeWidth: 0.5),
        controlInk: Color.white.resolved,
        controlAccent: Color.sunlight.resolved,
        map: .photo
    )
}

extension WidgetLook.Face {
    func font(size: CGFloat) -> Font {
        let font = Font.system(size: size, weight: weight.fontWeight, design: design.fontDesign).width(Font.Width(width))
        return italic ? font.italic() : font
    }
}

extension WidgetLook.Weight {
    var fontWeight: Font.Weight {
        switch self {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        }
    }
}

extension WidgetLook.Design {
    var fontDesign: Font.Design {
        switch self {
        case .standard: .default
        case .serif: .serif
        case .rounded: .rounded
        case .monospaced: .monospaced
        }
    }
}

extension Color {
    var resolved: Color.Resolved {
        resolve(in: EnvironmentValues())
    }
}
