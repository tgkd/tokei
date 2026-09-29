import SwiftUI

struct WeatherBadge: View {
    struct Trigger: Equatable {
        let status: WeatherFeed.Status
        let isScrubbing: Bool
        let isActive: Bool

        var isVisible: Bool {
            isActive && (isScrubbing || (status != .idle && status != .ready))
        }
    }

    @Environment(\.sceneStyle) private var style

    let status: WeatherFeed.Status
    let isScrubbing: Bool
    let shownTime: String?
    let retry: () -> Void

    var body: some View {
        let interface = style.interface
        Button(action: retry) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: interface.typography.symbolWeight))
                Text(message)
                    .font(interface.typography.caption(.footnote))
                    .lineLimit(1)
            }
            .foregroundStyle(interface.controlInk)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .contentShape(.capsule)
        }
        .buttonStyle(SurfaceButtonStyle(surface: interface.control, shape: Capsule()))
        .disabled(!canRetry)
        .accessibilityLabel(message)
        .accessibilityHint(canRetry ? "Tries to load the weather again" : "")
    }

    private var canRetry: Bool {
        !isScrubbing && (status == .stale || status == .unavailable)
    }

    private var symbol: String {
        if isScrubbing {
            return "hand.draw"
        }
        switch status {
        case .stale, .unavailable: return "arrow.clockwise"
        default: return "cloud"
        }
    }

    private var message: String {
        if isScrubbing {
            return "Weather updates on release"
        }
        switch status {
        case .loading: return "Loading weather…"
        case .updating: return shownTime.map { "Updating · showing \($0)" } ?? "Updating weather…"
        case .stale: return shownTime.map { "Showing \($0) weather · retry" } ?? "Weather is out of date · retry"
        case .unavailable: return "Weather unavailable · retry"
        case .idle, .ready: return ""
        }
    }
}
