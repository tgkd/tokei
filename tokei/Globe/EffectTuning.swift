import SwiftUI

struct EffectTuning {
    struct Press {
        var dentDepth: Double
        var dentRadius: Double
        var dentShade: Double
        var frost: Double
        var cracks: Double
        var squash: Double
        var pressSpring: Spring
        var releaseSpring: Spring
    }

    struct Pop {
        var height: Double
        var radius: Double
        var glow: Double
        var spring: Spring
    }

    struct Ripple {
        var tilt: Double
        var landShare: Double
        var flash: Double
        var displacement: Double
        var wavelength: Double
        var speed: Double
        var decay: Double
        var duration: Double
    }

    struct Fling {
        var stretchPerSpeed: Double
        var maximumStretch: Double
        var spring: Spring
    }

    var press: Press
    var pop: Pop
    var ripple: Ripple
    var fling: Fling
    var flightArc: Double
    var inflate: Spring?

    static let realistic = EffectTuning(
        press: Press(
            dentDepth: 0,
            dentRadius: 0.22,
            dentShade: 0,
            frost: 0,
            cracks: 0,
            squash: 0.025,
            pressSpring: Spring(duration: 0.3, bounce: 0.1),
            releaseSpring: Spring(duration: 0.6, bounce: 0.35)
        ),
        pop: Pop(height: 0, radius: 0.05, glow: 0.25, spring: Spring(duration: 0.6, bounce: 0.3)),
        ripple: Ripple(tilt: 0.12, landShare: 0, flash: 0, displacement: 0, wavelength: 0.1, speed: 0.8, decay: 2.0, duration: 1.5),
        fling: Fling(stretchPerSpeed: 0.008, maximumStretch: 0.04, spring: Spring(duration: 0.5, bounce: 0.4)),
        flightArc: 0.4,
        inflate: nil
    )

    static let toy = EffectTuning(
        press: Press(
            dentDepth: 0.08,
            dentRadius: 0.16,
            dentShade: 3.5,
            frost: 0,
            cracks: 0,
            squash: 0.03,
            pressSpring: Spring(duration: 0.25, bounce: 0.2),
            releaseSpring: Spring(duration: 0.55, bounce: 0.55)
        ),
        pop: Pop(height: 0.04, radius: 0.07, glow: 0, spring: Spring(duration: 0.5, bounce: 0.5)),
        ripple: Ripple(tilt: 0.1, landShare: 0, flash: 0, displacement: 0, wavelength: 0.1, speed: 0.9, decay: 2.2, duration: 1.6),
        fling: Fling(stretchPerSpeed: 0.012, maximumStretch: 0.06, spring: Spring(duration: 0.45, bounce: 0.5)),
        flightArc: 0.6,
        inflate: Spring(duration: 0.9, bounce: 0.3)
    )

    static let ice = EffectTuning(
        press: Press(
            dentDepth: 0.015,
            dentRadius: 0.14,
            dentShade: 0,
            frost: 0,
            cracks: 0.7,
            squash: 0.008,
            pressSpring: Spring(duration: 0.18, bounce: 0),
            releaseSpring: Spring(duration: 0.3, bounce: 0.15)
        ),
        pop: Pop(height: 0.015, radius: 0.05, glow: 0.35, spring: Spring(duration: 0.3, bounce: 0.3)),
        ripple: Ripple(tilt: 0.12, landShare: 1, flash: 0.5, displacement: 0, wavelength: 0.06, speed: 1.4, decay: 3, duration: 1.1),
        fling: Fling(stretchPerSpeed: 0.004, maximumStretch: 0.02, spring: Spring(duration: 0.22, bounce: 0.4)),
        flightArc: 0.5,
        inflate: Spring(duration: 0.6, bounce: 0.1)
    )
}

extension SceneStyle {
    var effects: EffectTuning {
        switch self {
        case .realistic: .realistic
        case .toy: .toy
        case .ice: .ice
        }
    }
}
