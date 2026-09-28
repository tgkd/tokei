import SwiftUI

struct DisplayTime: View {
    let date: Date
    let zone: TimeZone
    let font: Font
    let periodFont: Font

    var body: some View {
        Text(styled)
            .font(font)
            .monospacedDigit()
    }

    private var styled: AttributedString {
        var text = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: zone).attributedStyle)
        while let narrow = text.range(of: "\u{202F}") {
            var space = AttributedString(" ")
            space.font = periodFont
            text.replaceSubrange(narrow, with: space)
        }
        let periods = text.runs.filter { $0.dateField == .amPM }.map(\.range)
        for range in periods {
            text[range].font = periodFont
        }
        return text
    }
}
