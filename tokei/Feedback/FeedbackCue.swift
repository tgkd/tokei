import SwiftUI

struct FeedbackCue: Equatable {
    enum Kind: CaseIterable {
        case tick
        case dayTick
        case press
        case release
        case pop
        case snap
        case inflate
        case carve
    }

    let kind: Kind
    let style: SceneStyle
    let id = UUID()

    var haptic: SensoryFeedback? {
        switch kind {
        case .tick: nil
        case .dayTick: .impact(flexibility: .rigid, intensity: 0.7)
        case .press: .impact(flexibility: .soft, intensity: 0.5)
        case .release: nil
        case .pop: style == .ice ? .impact(flexibility: .rigid, intensity: 0.85) : .impact(weight: .medium, intensity: 0.8)
        case .snap: .impact(flexibility: .rigid, intensity: 0.9)
        case .inflate: .impact(flexibility: .soft, intensity: 1)
        case .carve: .impact(flexibility: .soft, intensity: 0.35)
        }
    }
}
