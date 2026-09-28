import CoreGraphics
import Foundation
import Observation
import WidgetKit
import simd

@MainActor
@Observable
final class SceneModel {
    var camera = OrbitCamera(yaw: 0, pitch: 0.3, distance: 3.8, centerY: 400)
    var cameraMotion: CameraMotion?
    var shift: Double
    var shiftGlide: ShiftGlide?
    var isScrubbing = false
    var style: SceneStyle {
        didSet {
            style.save()
            updateSound()
            if style.usesMesh && style != oldValue {
                inflate(announced: true)
            }
        }
    }
    var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: Self.soundKey)
            updateSound()
        }
    }
    var isForeground = true {
        didSet {
            updateSound()
        }
    }
    var reduceMotion = false
    var effects = SceneEffects()
    @ObservationIgnored private var pressFootprint = FootprintShape.random(radius: 0.08)
    private(set) var cue: FeedbackCue?
    private(set) var isGlobeReady = false
    private(set) var hasPlacedCamera = false
    let renderer = GlobeRenderer()
    @ObservationIgnored private let feedback = FeedbackPlayer()

    static let shiftRange = -72.0 * 60 ... 72.0 * 60
    private static let soundKey = "sound_enabled"
    private static let deliberatePress = 0.2

    init() {
        shift = Double(ZoneStorage.loadShift())
        style = SceneStyle.load()
        soundEnabled = UserDefaults.standard.object(forKey: Self.soundKey) as? Bool ?? true
        updateSound()
    }

    func prepareGlobe() async {
        await renderer?.loadTextures()
        isGlobeReady = renderer?.isReady ?? false
        if isGlobeReady && style.usesMesh {
            inflate(announced: false)
        }
    }

    func emit(_ kind: FeedbackCue.Kind) {
        let cue = FeedbackCue(kind: kind)
        self.cue = cue
        feedback.play(cue, style: style, soundEnabled: soundEnabled)
    }

    func press(at point: SIMD3<Double>, footprint: Double) {
        emit(.press)
        pressFootprint = FootprintShape.random(radius: footprint)
        stampSnow(at: point, shape: pressFootprint)
        guard !reduceMotion else { return }
        effects.press = SceneEffects.Press(point: point, start: Date())
    }

    func releasePress(moved: Bool) {
        guard var press = effects.press, press.release == nil else { return }
        let now = Date()
        press.release = now
        effects.press = press
        stampSnow(at: press.point, shape: pressFootprint)
        if !moved && now.timeIntervalSince(press.start) >= Self.deliberatePress {
            emit(.release)
        }
    }

    func pop(at point: SIMD3<Double>) {
        emit(.pop)
        stampSnow(at: point, shape: FootprintShape.random(radius: 0.035))
        guard !reduceMotion else { return }
        effects.pop = SceneEffects.Pop(point: point, start: Date())
    }

    private func stampSnow(at point: SIMD3<Double>, shape: FootprintShape) {
        let material = style.toyMaterial
        guard material.snowCover > 0, let snowCover = renderer?.snowCover else { return }
        let now = Date()
        let recovery = Double(material.snowRecovery)
        snowCover.stamp(at: point, shape: shape, recovery: recovery, now: now)
        effects.snow = SceneEffects.Snow(epoch: snowCover.epoch, until: now.addingTimeInterval(recovery))
    }

    func fling(axis: SIMD3<Double>, speed: Double) {
        guard !reduceMotion, length(axis) > 1e-6 else { return }
        let tuning = style.effects.fling
        let stretch = min(speed * tuning.stretchPerSpeed, tuning.maximumStretch)
        guard stretch > 0.002 else { return }
        effects.fling = SceneEffects.Fling(axis: normalize(axis), stretch: stretch, start: Date())
    }

    func settleEffects() {
        let hadSnow = effects.snow != nil
        effects = effects.settled(at: Date(), tuning: style.effects)
        if hadSnow && effects.snow == nil {
            renderer?.snowCover?.reset()
        }
    }

    func focus(on point: GeoPoint) {
        let target = destination.facing(point).clamped()
        let from = camera(at: Date())
        let turn = acos(min(max(dot(normalize(from.position), normalize(target.position)), -1), 1))
        fly(to: target, arc: reduceMotion ? 0 : style.effects.flightArc * turn / .pi)
    }

    private func inflate(announced: Bool) {
        if announced {
            emit(.inflate)
        }
        guard !reduceMotion, style.effects.inflate != nil else { return }
        effects.inflateStart = Date()
    }

    private func updateSound() {
        feedback.setSoundActive(isForeground && style.soundTimbre != nil && soundEnabled)
    }

    func camera(at date: Date) -> OrbitCamera {
        cameraMotion?.camera(at: date) ?? camera
    }

    var destination: OrbitCamera {
        guard let cameraMotion else { return camera }
        return cameraMotion.camera(at: cameraMotion.endDate)
    }

    func shift(at date: Date) -> Double {
        shiftGlide?.value(at: date) ?? shift
    }

    var committedShift: Int {
        Int(shift.rounded())
    }

    func interruptCamera() {
        guard let cameraMotion else { return }
        camera = cameraMotion.camera(at: Date())
        self.cameraMotion = nil
    }

    func fly(to target: OrbitCamera, duration: Double = 1.0, arc: Double = 0) {
        let now = Date()
        let from = camera(at: now)
        camera = from
        cameraMotion = .flight(start: now, from: from, to: target.clamped(), duration: duration, arc: arc)
    }

    func coast(yawVelocity: Double, pitchVelocity: Double) {
        let motion = CameraMotion.inertia(start: Date(), from: camera, yawVelocity: yawVelocity, pitchVelocity: pitchVelocity)
        if motion.endDate.timeIntervalSinceNow > 0.05 {
            cameraMotion = motion
        }
    }

    func settle(_ motion: CameraMotion) {
        guard cameraMotion == motion else { return }
        camera = motion.camera(at: motion.endDate)
        cameraMotion = nil
    }

    func fit(to rect: CGRect, in size: CGSize, facing point: GeoPoint?) {
        let focal = GlobeFrame.focalLength(for: size)
        let radius = min(rect.width, rect.height) * 0.43
        var target = destination
        target.distance = OrbitCamera.distance(fittingRadius: radius, focalLength: focal)
        target.centerY = rect.midY
        if !hasPlacedCamera {
            hasPlacedCamera = true
            if let point {
                target = target.facing(point)
            }
            camera = target.clamped()
            cameraMotion = nil
            return
        }
        fly(to: target, duration: 0.55)
    }

    func scrub(to minutes: Double) {
        shiftGlide = nil
        isScrubbing = true
        shift = rubberBand(minutes)
    }

    func releaseScrub(velocity: Double, now: Date) {
        isScrubbing = false
        let projected = shift + velocity * 0.32
        let quarter = 15.0 * 60
        let projectedDate = now.timeIntervalSince1970 + projected * 60
        let snappedDate = (projectedDate / quarter).rounded() * quarter
        var target = (snappedDate - now.timeIntervalSince1970) / 60
        target = min(max(target, Self.shiftRange.lowerBound), Self.shiftRange.upperBound)
        if abs(target) < 7.5 && abs(projected) < 7.5 {
            target = 0
        }
        shiftGlide = ShiftGlide(start: Date(), origin: shift, velocity: velocity, target: target)
    }

    func resetShift() {
        let now = Date()
        let current = shift(at: now)
        shift = current
        shiftGlide = ShiftGlide(start: now, origin: current, velocity: 0, target: 0)
    }

    func nudgeShift(by minutes: Double) {
        let now = Date()
        let current = shift(at: now)
        shift = current
        let target = min(max(current + minutes, Self.shiftRange.lowerBound), Self.shiftRange.upperBound)
        shiftGlide = ShiftGlide(start: now, origin: current, velocity: 0, target: target)
    }

    func settle(_ glide: ShiftGlide) {
        guard shiftGlide == glide else { return }
        if glide.target == 0 && abs(glide.origin) >= 1 {
            emit(.snap)
        }
        shift = glide.target
        shiftGlide = nil
        ZoneStorage.saveShift(committedShift)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func syncShiftFromStorage() {
        guard !isScrubbing, shiftGlide == nil else { return }
        let stored = Double(ZoneStorage.loadShift())
        if stored != shift {
            shift = stored
        }
    }

    private func rubberBand(_ minutes: Double) -> Double {
        let lower = Self.shiftRange.lowerBound
        let upper = Self.shiftRange.upperBound
        if minutes > upper {
            return upper + 90 * (1 - 1 / ((minutes - upper) / 90 + 1))
        }
        if minutes < lower {
            return lower - 90 * (1 - 1 / ((lower - minutes) / 90 + 1))
        }
        return minutes
    }
}
