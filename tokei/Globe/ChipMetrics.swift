import SwiftUI
import UIKit

enum ChipMetrics {
    struct Fonts {
        let name: UIFont
        let time: UIFont
        let detail: UIFont

        init(_ chip: ChipLook) {
            name = ChipMetrics.font(chip.name)
            time = ChipMetrics.font(chip.time)
            detail = ChipMetrics.font(chip.detail)
        }
    }

    static let dotRadius: CGFloat = 5.5
    static let gap: CGFloat = 4

    private static let realisticFonts = Fonts(SceneStyle.realistic.interface.chip)
    private static let toyFonts = Fonts(SceneStyle.toy.interface.chip)
    private static let iceFonts = Fonts(SceneStyle.ice.interface.chip)
    private static let chromeFonts = Fonts(SceneStyle.chrome.interface.chip)
    private static let paperFonts = Fonts(SceneStyle.paper.interface.chip)
    private static let weatherFonts = Fonts(SceneStyle.weather.interface.chip)
    private static let sakuraFonts = Fonts(SceneStyle.sakura.interface.chip)
    private static let magmaFonts = Fonts(SceneStyle.magma.interface.chip)
    private static let abyssFonts = Fonts(SceneStyle.abyss.interface.chip)
    private static let pixelFonts = Fonts(SceneStyle.pixel.interface.chip)

    static func fonts(for style: SceneStyle) -> Fonts {
        switch style {
        case .realistic: realisticFonts
        case .toy: toyFonts
        case .ice: iceFonts
        case .chrome: chromeFonts
        case .paper: paperFonts
        case .weather: weatherFonts
        case .sakura: sakuraFonts
        case .magma: magmaFonts
        case .abyss: abyssFonts
        case .pixel: pixelFonts
        }
    }

    static func displayName(_ name: String, style: SceneStyle) -> String {
        style.interface.chip.uppercasedName ? name.uppercased() : name
    }

    static let weatherSpacing: CGFloat = 4
    static let expandedCorner: CGFloat = 16
    static let expandedInset: CGFloat = 4

    static func corner(_ chip: ChipLook, isExpanded: Bool) -> CGFloat {
        isExpanded ? min(chip.corner, expandedCorner) : chip.corner
    }

    static func padding(_ chip: ChipLook, isExpanded: Bool) -> EdgeInsets {
        let inset = isExpanded ? expandedInset : 0
        return EdgeInsets(top: chip.verticalPadding + inset, leading: chip.horizontalPadding + inset, bottom: chip.verticalPadding + inset, trailing: chip.horizontalPadding + inset)
    }

    static func size(name: String, time: String, detail: String?, weather: ChipWeather?, style: SceneStyle) -> CGSize {
        let chip = style.interface.chip
        let fonts = fonts(for: style)
        let nameWidth = width(of: displayName(name, style: style), font: fonts.name)
        let timeWidth = width(of: time, font: fonts.time)
        var width = nameWidth + chip.spacing + timeWidth
        var height = ceil(max(fonts.name.lineHeight, fonts.time.lineHeight))
        if let detail {
            width = max(width, self.width(of: detail, font: fonts.detail))
            height += chip.lineSpacing + ceil(fonts.detail.lineHeight)
        }
        if let weather {
            let symbol = UIImage(systemName: weather.symbol, withConfiguration: UIImage.SymbolConfiguration(font: fonts.detail))?.size ?? .zero
            let text = weather.text.isEmpty ? 0 : weatherSpacing + self.width(of: weather.text, font: fonts.detail)
            width = max(width, ceil(symbol.width) + text)
            height += chip.lineSpacing + ceil(max(fonts.detail.lineHeight, symbol.height))
        }
        return CGSize(
            width: ceil(width + padding(chip, isExpanded: detail != nil || weather != nil).leading * 2),
            height: ceil(height + padding(chip, isExpanded: detail != nil || weather != nil).top * 2 + chip.surface.depth)
        )
    }

    private static func width(of text: String, font: UIFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private static func font(_ face: ChipLook.Face) -> UIFont {
        let base = UIFont.systemFont(ofSize: face.size, weight: uiWeight(face.weight), width: uiWidth(face.width))
        var descriptor = base.fontDescriptor
        if let design = systemDesign(face.design), let designed = descriptor.withDesign(design) {
            descriptor = designed
        }
        if face.italic, let slanted = descriptor.withSymbolicTraits(descriptor.symbolicTraits.union(.traitItalic)) {
            descriptor = slanted
        }
        if face.monospacedDigits {
            descriptor = descriptor.addingAttributes([
                .featureSettings: [[
                    UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                    UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector,
                ]],
            ])
        }
        return UIFont(descriptor: descriptor, size: face.size)
    }

    private static func uiWeight(_ weight: Font.Weight) -> UIFont.Weight {
        switch weight {
        case .ultraLight: .ultraLight
        case .thin: .thin
        case .light: .light
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        case .black: .black
        default: .regular
        }
    }

    private static func uiWidth(_ width: Font.Width) -> UIFont.Width {
        switch width {
        case .compressed: .compressed
        case .condensed: .condensed
        case .expanded: .expanded
        default: .standard
        }
    }

    private static func systemDesign(_ design: Font.Design) -> UIFontDescriptor.SystemDesign? {
        switch design {
        case .rounded: .rounded
        case .serif: .serif
        case .monospaced: .monospaced
        default: nil
        }
    }
}
