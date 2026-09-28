import SwiftUI

extension SceneLook {
    static let realistic = SceneLook(
        name: "Realistic",
        backdrop: .linear(red: 0.018, green: 0.022, blue: 0.035),
        accent: .sunlight,
        effects: .realistic,
        sound: nil,
        mesh: nil
    )
}

extension EffectTuning {
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
}
