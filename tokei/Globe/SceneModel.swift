import CoreGraphics
import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class SceneModel {
    var camera = OrbitCamera(yaw: 0, pitch: 0.3, distance: 3.8, centerY: 400)
    var cameraMotion: CameraMotion?
    var shift: Double
    var shiftGlide: ShiftGlide?
    var isScrubbing = false
    private(set) var isGlobeReady = false
    private(set) var hasPlacedCamera = false
    let renderer = GlobeRenderer()

    static let shiftRange = -72.0 * 60 ... 72.0 * 60

    init() {
        shift = Double(ZoneStorage.loadShift())
    }

    func prepareGlobe() async {
        await renderer?.loadTextures()
        isGlobeReady = renderer?.isReady ?? false
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

    func fly(to target: OrbitCamera, duration: Double = 1.0) {
        let now = Date()
        let from = camera(at: now)
        camera = from
        cameraMotion = .flight(start: now, from: from, to: target.clamped(), duration: duration)
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
