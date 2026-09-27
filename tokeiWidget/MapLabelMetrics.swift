import SwiftUI
import UIKit

enum MapLabelMetrics {
    static let nameFont = UIFont.systemFont(ofSize: 9, weight: .semibold)
    static let timeFont = UIFont.monospacedDigitSystemFont(ofSize: 10, weight: .semibold)
    static let horizontalPadding: CGFloat = 5
    static let verticalPadding: CGFloat = 3
    static let dotRadius: CGFloat = 3

    static func size(name: String, time: String) -> CGSize {
        let nameWidth = ceil((name as NSString).size(withAttributes: [.font: nameFont]).width)
        let timeWidth = ceil((time as NSString).size(withAttributes: [.font: timeFont]).width)
        let height = ceil(nameFont.lineHeight) + ceil(timeFont.lineHeight) + verticalPadding * 2
        return CGSize(width: max(nameWidth, timeWidth) + horizontalPadding * 2, height: height)
    }
}
