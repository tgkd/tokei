import SwiftUI
import UIKit

enum MapLabelMetrics {
    static let horizontalPadding: CGFloat = 5
    static let verticalPadding: CGFloat = 3
    static let dotRadius: CGFloat = 3

    static func corner(_ label: WidgetLook.Label) -> CGFloat {
        label.corner / 2
    }

    static func sidePadding(corner: CGFloat) -> CGFloat {
        guard corner > verticalPadding else { return horizontalPadding }
        let rise = corner - verticalPadding
        return horizontalPadding + corner - (corner * corner - rise * rise).squareRoot()
    }

    static func nameFont(_ typography: WidgetLook.Typography) -> UIFont {
        typography.labelName.uiFont(size: 9)
    }

    static func timeFont(_ typography: WidgetLook.Typography) -> UIFont {
        typography.labelTime.uiFont(size: 10, monospacedDigits: true)
    }

    static func size(name: String, time: String, typography: WidgetLook.Typography, corner: CGFloat) -> CGSize {
        let nameFont = Self.nameFont(typography)
        let timeFont = Self.timeFont(typography)
        let nameWidth = ceil((name as NSString).size(withAttributes: [.font: nameFont]).width)
        let timeWidth = ceil((time as NSString).size(withAttributes: [.font: timeFont]).width)
        let height = ceil(nameFont.lineHeight) + ceil(timeFont.lineHeight) + verticalPadding * 2
        return CGSize(width: max(nameWidth, timeWidth) + sidePadding(corner: corner) * 2, height: height)
    }
}

extension WidgetLook.Face {
    func uiFont(size: CGFloat, monospacedDigits: Bool = false) -> UIFont {
        var descriptor = UIFont.systemFont(ofSize: size, weight: weight.uiFontWeight, width: UIFont.Width(rawValue: width)).fontDescriptor
        if let design = design.uiFontDesign, let designed = descriptor.withDesign(design) {
            descriptor = designed
        }
        if italic, let slanted = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.traitItalic)) {
            descriptor = slanted
        }
        if monospacedDigits {
            descriptor = descriptor.addingAttributes([
                .featureSettings: [[UIFontDescriptor.FeatureKey.type: kNumberSpacingType, UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector]],
            ])
        }
        return UIFont(descriptor: descriptor, size: size)
    }
}

private extension WidgetLook.Weight {
    var uiFontWeight: UIFont.Weight {
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

private extension WidgetLook.Design {
    var uiFontDesign: UIFontDescriptor.SystemDesign? {
        switch self {
        case .standard: nil
        case .serif: .serif
        case .rounded: .rounded
        case .monospaced: .monospaced
        }
    }
}
