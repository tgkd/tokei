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
        var followHaptic = false
        var cutoff: Double? = nil
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

    struct Petals {
        var lifetime: Double
        var stagger: Double
        var size: Double
        var fall: Double
        var drag: Double
        var launch: Double
        var flutter: Double
        var spin: Double
        var lift: Double
        var shower: Int
        var showerDelay: Double
        var pop: Int
        var flingPerSpeed: Double
        var flingMaximum: Int
        var stroke: Int
        var strokeSpacing: Double
        var windPerSpeed: Double
    }

    var press: Press
    var pop: Pop
    var ripple: Ripple
    var fling: Fling
    var flightArc: Double
    var inflate: Spring?
    var drag = Drag()
    var petals: Petals?
}
