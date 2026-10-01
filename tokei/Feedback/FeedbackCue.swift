import SwiftUI

struct CueContext: Hashable, Sendable {
    enum Surface: Hashable, Sendable {
        case land
        case sea
    }

    var pitch: Int?
    var direction = 0
    var tension = 0
    var surface: Surface?

    static let none = CueContext()

    var seed: UInt64 {
        let pitchByte = UInt64((pitch ?? 99) + 128)
        let directionByte = UInt64(direction + 2)
        let tensionByte = UInt64(tension)
        return (pitchByte << 24) | (directionByte << 16) | (tensionByte << 8) | UInt64(surfaceCode)
    }

    private var surfaceCode: Int {
        switch surface {
        case .land: 1
        case .sea: 2
        case nil: 0
        }
    }
}

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
    var context: CueContext = .none

    var haptic: SensoryFeedback? {
        switch kind {
        case .tick: nil
        case .dayTick: .impact(flexibility: .rigid, intensity: 0.7)
        case .press: .impact(flexibility: .soft, intensity: 0.5)
        case .release: nil
        case .pop: popHaptic
        case .snap: .impact(flexibility: .rigid, intensity: 0.9)
        case .inflate: .impact(flexibility: .soft, intensity: 1)
        case .carve: .impact(flexibility: .soft, intensity: 0.35)
        }
    }

    private var popHaptic: SensoryFeedback {
        switch style {
        case .ice, .pixel: .impact(flexibility: .rigid, intensity: 0.85)
        case .sakura: .impact(flexibility: .soft, intensity: 0.55)
        case .magma: .impact(weight: .heavy, intensity: 0.9)
        case .repeater: .impact(weight: .light, intensity: 0.55)
        case .garden: .impact(flexibility: .soft, intensity: 0.7)
        case .mosaic: .impact(flexibility: .rigid, intensity: 0.6)
        case .knit: .impact(flexibility: .soft, intensity: 0.6)
        default: .impact(weight: .medium, intensity: 0.8)
        }
    }
}
