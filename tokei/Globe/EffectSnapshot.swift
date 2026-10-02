import simd

struct EffectUniforms {
    var shapeX: SIMD4<Float>
    var shapeY: SIMD4<Float>
    var shapeZ: SIMD4<Float>
    var unshapeX: SIMD4<Float>
    var unshapeY: SIMD4<Float>
    var unshapeZ: SIMD4<Float>
    var dent: SIMD4<Float>
    var bump: SIMD4<Float>
    var ripple: SIMD4<Float>
    var radii: SIMD4<Float>
    var wave: SIMD4<Float>
    var state: SIMD4<Float>
    var detail: SIMD4<Float>
}

struct EffectSnapshot: Equatable {
    var shape = matrix_identity_double3x3
    var dentPoint = SIMD3<Double>(0, 0, 1)
    var dentDepth = 0.0
    var dentRadius = 1.0
    var dentShade = 0.0
    var frost = 0.0
    var cracks = 0.0
    var bumpPoint = SIMD3<Double>(0, 0, 1)
    var bumpHeight = 0.0
    var bumpRadius = 1.0
    var glow = 0.0
    var rippleOrigin = SIMD3<Double>(0, 0, 1)
    var rippleAge = -1.0
    var rippleTilt = 0.0
    var rippleLandShare = 0.0
    var rippleFlash = 0.0
    var rippleDisplacement = 0.0
    var rippleWavelength = 1.0
    var rippleSpeed = 0.0
    var rippleDecay = 0.0
    var inflate = 1.0
    var snowClock = 0.0
    var stirClock = 0.0

    static let none = EffectSnapshot()

    var isActive: Bool {
        var still = self
        still.stirClock = 0
        return still != .none
    }

    func place(_ direction: SIMD3<Double>, surfaceRadius: Double) -> SIMD3<Double> {
        place(direction, lift: (surfaceRadius - 1) * inflate)
    }

    func place(_ direction: SIMD3<Double>, lift: Double) -> SIMD3<Double> {
        shape * (direction * (1 + lift + offset(along: direction)))
    }

    func offset(along direction: SIMD3<Double>) -> Double {
        var offset = bumpHeight * Self.weight(direction, bumpPoint, bumpRadius)
            - dentDepth * Self.weight(direction, dentPoint, dentRadius)
        if rippleAge >= 0 && rippleDisplacement != 0 {
            let angle = acos(min(max(dot(direction, rippleOrigin), -1), 1))
            offset += rippleDisplacement * rippleProfile(angle: angle)
        }
        return offset
    }

    var uniforms: EffectUniforms {
        let unshape = shape.inverse
        return EffectUniforms(
            shapeX: Self.column(shape[0]),
            shapeY: Self.column(shape[1]),
            shapeZ: Self.column(shape[2]),
            unshapeX: Self.column(unshape[0]),
            unshapeY: Self.column(unshape[1]),
            unshapeZ: Self.column(unshape[2]),
            dent: Self.point(dentPoint, dentDepth),
            bump: Self.point(bumpPoint, bumpHeight),
            ripple: Self.point(rippleOrigin, rippleAge),
            radii: SIMD4(Float(dentRadius), Float(bumpRadius), Float(glow), Float(inflate)),
            wave: SIMD4(Float(rippleTilt), Float(rippleDisplacement), Float(rippleWavelength), Float(rippleSpeed)),
            state: SIMD4(Float(rippleDecay), isActive ? 1 : 0, Float(dentShade), Float(snowClock)),
            detail: SIMD4(Float(frost), Float(cracks), Float(rippleLandShare), Float(rippleFlash))
        )
    }

    private func rippleProfile(angle: Double) -> Double {
        let offset = angle - rippleSpeed * rippleAge
        let envelope = exp(-rippleDecay * rippleAge) * exp(-(offset / rippleWavelength) * (offset / rippleWavelength))
        return envelope * sin(2 * .pi * offset / rippleWavelength)
    }

    private static func weight(_ direction: SIMD3<Double>, _ center: SIMD3<Double>, _ radius: Double) -> Double {
        exp(-(1 - dot(direction, center)) / (radius * radius))
    }

    private static func column(_ vector: SIMD3<Double>) -> SIMD4<Float> {
        SIMD4(SIMD3<Float>(vector), 0)
    }

    private static func point(_ vector: SIMD3<Double>, _ value: Double) -> SIMD4<Float> {
        SIMD4(SIMD3<Float>(vector), Float(value))
    }
}
