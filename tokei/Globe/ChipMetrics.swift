import SwiftUI
import UIKit

enum ChipMetrics {
    static let nameFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
    static let timeFont = UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
    static let detailFont = UIFont.systemFont(ofSize: 11, weight: .medium)
    static let horizontalPadding: CGFloat = 9
    static let verticalPadding: CGFloat = 5
    static let spacing: CGFloat = 6
    static let lineSpacing: CGFloat = 1
    static let dotRadius: CGFloat = 4.5
    static let gap: CGFloat = 4

    static func size(name: String, time: String, detail: String?) -> CGSize {
        let nameWidth = width(of: name, font: nameFont)
        let timeWidth = width(of: time, font: timeFont)
        var width = nameWidth + spacing + timeWidth
        var height = ceil(nameFont.lineHeight)
        if let detail {
            width = max(width, self.width(of: detail, font: detailFont))
            height += lineSpacing + ceil(detailFont.lineHeight)
        }
        return CGSize(width: ceil(width + horizontalPadding * 2), height: ceil(height + verticalPadding * 2))
    }

    private static func width(of text: String, font: UIFont) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }
}
