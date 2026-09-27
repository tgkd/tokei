import SwiftUI

extension Color {
    static let sunlight = Color(red: 1.0, green: 0.76, blue: 0.40)
    static let space = Color(red: 0.018, green: 0.022, blue: 0.035)
}

extension ShapeStyle where Self == Color {
    static var sunlight: Color {
        .sunlight
    }

    static var space: Color {
        .space
    }
}
