import SwiftUI

struct SheetBackground: ViewModifier {
    let color: Color?

    func body(content: Content) -> some View {
        if let color {
            content.presentationBackground(color)
        } else {
            content
        }
    }
}
