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
            if style != oldValue {
                resetDisturbance()
            }
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
            if !isForeground {
                effects.petals = []
                cancelSequence()
                feedback.cancel(trainTicket)
                trainTicket = nil
                markStroke = nil
                renderer?.markMap?.reset()
                marksRevision = renderer?.markMap?.revision ?? marksRevision
            }
        }
    }
    var reduceMotion = false {
        didSet {
            if reduceMotion {
                effects.petals = []
            }
        }
    }
    var effects = SceneEffects()
    @ObservationIgnored private var pressFootprint = FootprintShape.random(radius: 0.08)
    @ObservationIgnored private var pressPoint: SIMD3<Double>?
    @ObservationIgnored private var pressStart: Date?
    @ObservationIgnored private var pressTicket: SoundBoard.SoundTicket?
    @ObservationIgnored private var stroke: SurfaceStroke?
    @ObservationIgnored private var petalTrail: SIMD3<Double>?
    @ObservationIgnored private var trainTicket: FeedbackTicket?
    @ObservationIgnored private var sequenceTicket: FeedbackTicket?
    @ObservationIgnored private var strikeTask: Task<Void, Never>?
    private(set) var cue: FeedbackCue?
    private(set) var isGlobeReady = false
    private(set) var hasPlacedCamera = false
    private(set) var marksRevision = 0
    var striking: UUID?
    @ObservationIgnored private var markStroke: MarkStroke?
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

    @discardableResult
    func emit(_ kind: FeedbackCue.Kind, context: CueContext = .none) -> SoundBoard.SoundTicket? {
        let cue = FeedbackCue(kind: kind, style: style, context: context)
        self.cue = cue
        return feedback.play(cue, style: style, soundEnabled: soundEnabled)
    }

    private func playSequence(_ sequence: SoundSequence) {
        cancelSequence()
        sequenceTicket = feedback.play(sequence, style: style, soundEnabled: soundEnabled)
    }

    private func cancelSequence() {
        feedback.cancel(sequenceTicket)
        sequenceTicket = nil
        striking = nil
        strikeTask?.cancel()
        strikeTask = nil
    }

    func strike(hour: Int, minute: Int, zone: Zone) {
        guard let schedule = style.look.strikes else { return }
        playSequence(schedule.sequence(hour, minute))
        striking = zone.id
        let duration = schedule.duration(hour, minute)
        strikeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration + 0.4))
            guard !Task.isCancelled else { return }
            self?.striking = nil
        }
    }

    private func surface(at point: SIMD3<Double>) -> CueContext.Surface? {
        guard let mesh = style.mesh, let coast = renderer?.toyMesh?.shapes[mesh.shape]?.surface.coast else { return nil }
        return coast.sample(point) > 0 ? .land : .sea
    }

    var allowsSurfaceDrag: Bool {
        guard let mesh = style.mesh else { return false }
        return mesh.snow != nil || mesh.marks != nil || !reduceMotion
    }

    func press(at point: SIMD3<Double>, footprint: Double) {
        cancelSequence()
        pressStart = Date()
        pressTicket = emit(.press, context: CueContext(surface: surface(at: point)))
        pressPoint = point
        pressFootprint = FootprintShape.random(radius: footprint)
        stampSnow(at: point, shape: pressFootprint)
        guard !reduceMotion else { return }
        effects.press = SceneEffects.Press(point: point, start: Date())
    }

    func releasePress(moved: Bool) {
        cutPressIfReleasedEarly()
        guard var press = effects.press, press.release == nil else { return }
        let now = Date()
        press.release = now
        effects.press = press
        stampSnow(at: press.point, shape: pressFootprint)
        if !moved && now.timeIntervalSince(press.start) >= Self.deliberatePress {
            emit(.release)
        }
    }

    private func cutPressIfReleasedEarly() {
        if let cutoff = style.effects.press.cutoff, let pressStart, Date().timeIntervalSince(pressStart) < cutoff {
            feedback.cancel(pressTicket)
        }
        pressStart = nil
        pressTicket = nil
    }

    func prewarmPops(_ contexts: [CueContext]) {
        feedback.prewarm(.pop, contexts: contexts, style: style, soundEnabled: soundEnabled)
    }

    func pop(at point: SIMD3<Double>, context: CueContext = .none) {
        cancelSequence()
        emit(.pop, context: context)
        if let popEcho = style.look.popEcho {
            playSequence(popEcho)
        }
        stampSnow(at: point, shape: FootprintShape.random(radius: 0.035))
        if let marks = style.mesh?.marks, let stamp = marks.pop, let markMap = renderer?.markMap {
            markMap.stamp(stamp, at: point, peak: markPeak(marks, now: Date()))
            marksRevision = markMap.revision
        }
        guard !reduceMotion else { return }
        effects.pop = SceneEffects.Pop(point: point, start: Date())
        if let petals = style.effects.petals {
            releasePetals(around: point, spread: 0.06, count: petals.pop)
        }
    }

    func beginSurfaceDrag(at point: SIMD3<Double>?, footprint: Double, location: CGPoint) {
        cancelSequence()
        interruptCamera()
        emit(.carve)
        let now = Date()
        let tuning = style.effects.drag
        var stroke = SurfaceStroke(trail: .random(radius: footprint * tuning.trailWidth), location: location, time: now)
        if let pressPoint, let point, acos(min(max(dot(pressPoint, point), -1), 1)) < stroke.trail.radius * 4 {
            stroke.trail.last = pressPoint
            if let snow = style.mesh?.snow, let snowCover = renderer?.snowCover {
                let hold = snow.recovery * tuning.trailHold
                snowCover.stamp(at: pressPoint, shape: pressFootprint, recovery: snow.recovery, hold: hold, now: now)
                extendSnow(from: snowCover, until: now.addingTimeInterval(snow.recovery + hold))
            }
        }
        self.stroke = stroke
        petalTrail = nil
        if let marks = style.mesh?.marks {
            markStroke = MarkStroke(halfWidth: footprint * marks.width)
        }
        dragSurface(to: point, location: location)
    }

    func dragSurface(to point: SIMD3<Double>?, location: CGPoint) {
        guard var stroke else { return }
        let now = Date()
        let tuning = style.effects.drag
        if let point {
            if let snow = style.mesh?.snow, let snowCover = renderer?.snowCover {
                let hold = snow.recovery * tuning.trailHold
                snowCover.carve(from: stroke.trail.last ?? point, to: point, trail: stroke.trail, recovery: snow.recovery, hold: hold, now: now)
                extendSnow(from: snowCover, until: now.addingTimeInterval(snow.recovery + hold))
            }
            if let marks = style.mesh?.marks, let markMap = renderer?.markMap, var mark = markStroke {
                markMap.sweep(to: point, stroke: &mark, brush: marks.drag, peak: markPeak(marks, now: now))
                markStroke = mark
                marksRevision = markMap.revision
            }
            stroke.trail.advance(to: point)
            if var press = effects.press, press.release == nil {
                press.pull(to: point, at: now, spring: tuning.follow)
                effects.press = press
            }
            brushPetals(at: point)
        } else {
            stroke.trail.last = nil
            markStroke?.last = nil
        }
        if let strength = stroke.advance(to: location, at: now, onSurface: point != nil, spacing: tuning.grainSpacing) {
            feedback.grain(.carve, style: style, soundEnabled: soundEnabled, strength: strength)
        }
        self.stroke = stroke
    }

    func endSurfaceDrag() {
        guard stroke != nil else { return }
        stroke = nil
        cutPressIfReleasedEarly()
        markStroke = nil
        guard var press = effects.press, press.release == nil else { return }
        press.release = Date()
        effects.press = press
        if style.mesh?.snow == nil {
            emit(.release)
        }
    }

    private func brushPetals(at point: SIMD3<Double>) {
        guard let petals = style.effects.petals else { return }
        guard let last = petalTrail else {
            petalTrail = point
            return
        }
        let travel = acos(min(max(dot(last, point), -1), 1))
        guard travel >= petals.strokeSpacing else { return }
        releasePetals(around: point, spread: petals.strokeSpacing * 0.6, count: petals.stroke, wind: normalize(point - last) * petals.windPerSpeed)
        petalTrail = point
    }

    private func releasePetals(around origin: SIMD3<Double>, spread: Double, count: Int, wind: SIMD3<Double> = .zero, delay: Double = 0) {
        guard !reduceMotion, style.mesh?.petals != nil, count > 0, effects.admits(petals: count) else { return }
        let now = Date()
        let view = camera(at: now)
        let forward = -normalize(view.position)
        let right = normalize(cross(forward, SIMD3(0, 1, 0)))
        let up = cross(right, forward)
        effects.petals.append(
            PetalBurst(
                origin: normalize(origin),
                spread: spread,
                down: -up,
                wind: wind,
                start: now.addingTimeInterval(delay),
                count: count,
                seed: UInt32.random(in: 0..<1024)
            )
        )
    }

    private func stampSnow(at point: SIMD3<Double>, shape: FootprintShape) {
        guard let snow = style.mesh?.snow, snow.footprints, let snowCover = renderer?.snowCover else { return }
        let now = Date()
        snowCover.stamp(at: point, shape: shape, recovery: snow.recovery, now: now)
        extendSnow(from: snowCover, until: now.addingTimeInterval(snow.recovery))
    }

    private func extendSnow(from snowCover: SnowCover, until end: Date) {
        let until = max(effects.snow?.until ?? end, end)
        effects.snow = SceneEffects.Snow(epoch: snowCover.epoch, until: until)
    }

    func fling(axis: SIMD3<Double>, speed: Double) {
        guard !reduceMotion, length(axis) > 1e-6 else { return }
        if let petals = style.effects.petals {
            let count = min(Int(speed * petals.flingPerSpeed), petals.flingMaximum)
            if count >= 4 {
                releasePetals(around: normalize(camera(at: Date()).position), spread: 1.1, count: count, wind: normalize(axis) * min(speed, 4) * petals.windPerSpeed)
            }
        }
        let tuning = style.effects.fling
        let stretch = min(speed * tuning.stretchPerSpeed, tuning.maximumStretch)
        guard stretch > 0.002 else { return }
        effects.fling = SceneEffects.Fling(axis: normalize(axis), stretch: stretch, start: Date())
    }

    private func resetDisturbance() {
        stroke = nil
        pressPoint = nil
        petalTrail = nil
        effects.snow = nil
        effects.petals = []
        renderer?.snowCover?.reset()
        markStroke = nil
        renderer?.markMap?.reset()
        marksRevision = renderer?.markMap?.revision ?? marksRevision
    }

    func settleEffects() {
        let hadSnow = effects.snow != nil
        effects = effects.settled(at: Date(), tuning: style.effects)
        if hadSnow && effects.snow == nil {
            renderer?.snowCover?.reset()
            if style.mesh?.marks?.recovery != nil, let markMap = renderer?.markMap {
                markStroke?.last = nil
                markMap.reset()
                marksRevision = markMap.revision
            }
        }
    }

    private func markPeak(_ marks: MarkSettings, now: Date) -> Double? {
        guard let recovery = marks.recovery, let snowCover = renderer?.snowCover else { return nil }
        if effects.snow == nil {
            snowCover.reset()
        }
        extendSnow(from: snowCover, until: now.addingTimeInterval(marks.hold + recovery))
        return now.timeIntervalSince(snowCover.epoch) + marks.hold
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
        if let petals = style.effects.petals {
            releasePetals(around: normalize(camera(at: Date()).position), spread: 1.2, count: petals.shower, delay: petals.showerDelay)
        }
    }

    private func updateSound() {
        feedback.setSoundActive(isForeground && style.soundTimbre != nil && soundEnabled, timbre: style.soundTimbre)
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
        feedback.cancel(trainTicket)
        trainTicket = nil
        cancelSequence()
        guard let cameraMotion else { return }
        camera = cameraMotion.camera(at: Date())
        self.cameraMotion = nil
    }

    func fly(to target: OrbitCamera, duration: Double = 1.0, arc: Double = 0) {
        feedback.cancel(trainTicket)
        trainTicket = nil
        let now = Date()
        let from = camera(at: now)
        camera = from
        cameraMotion = .flight(start: now, from: from, to: target.clamped(), duration: duration, arc: arc)
    }

    func coast(yawVelocity: Double, pitchVelocity: Double) {
        let motion = CameraMotion.inertia(start: Date(), from: camera, yawVelocity: yawVelocity, pitchVelocity: pitchVelocity)
        guard motion.endDate.timeIntervalSinceNow > 0.05 else { return }
        cameraMotion = motion
        feedback.cancel(trainTicket)
        trainTicket = nil
        if let train = style.soundTimbre?.train {
            trainTicket = feedback.train(train, speed: hypot(yawVelocity, pitchVelocity), style: style, soundEnabled: soundEnabled)
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
