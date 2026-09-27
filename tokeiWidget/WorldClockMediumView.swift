import SwiftUI
import WidgetKit

struct WorldClockMediumView: View {
    let entry: ClockEntry

    var body: some View {
        DayNightMapView(
            entry: entry,
            labelInsets: EdgeInsets(top: 7, leading: 7, bottom: 7, trailing: 7),
            reservedCorner: CGSize(width: 136, height: 42)
        )
        .overlay(alignment: .bottomTrailing) {
            ShiftControls(shiftMinutes: entry.shiftMinutes)
                .padding(8)
        }
    }
}
