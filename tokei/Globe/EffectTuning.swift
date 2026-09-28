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

    struct Drag {
        var follow = Spring(duration: 0.16, bounce: 0.25)
        var trailWidth = 1.0
        var trailHold = 1.0
        var grainSpacing = 12.0
        var grainSharpness = 0.45
    }

    var press: Press
    var pop: Pop
    var ripple: Ripple
    var fling: Fling
    var flightArc: Double
    var inflate: Spring?
    var drag = Drag()
}
