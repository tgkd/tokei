import SwiftUI

struct GlobeScene: View {
    @Environment(SceneModel.self) private var scene
    @Environment(ClockStore.self) private var store
    @Environment(WeatherFeed.self) private var weather

    let date: Date
    let isShifted: Bool
    let focusRect: CGRect

    @State private var cache = MarkerLayoutCache()
    @State private var touch = GlobeTouch()
    @State private var dragOrigin: OrbitCamera?
    @State private var dragStart: CGSize = .zero
    @State private var dragRadius: Double = 1
    @State private var pinchOrigin: Double?

    private static let refillInterval = 1.0 / 30

    private var schedule: AnimationTimelineSchedule {
        let cadence = scene.cameraMotion == nil && scene.shiftGlide == nil ? scene.effects.cadence : .moving
        return .animation(minimumInterval: cadence == .refilling ? Self.refillInterval : nil, paused: cadence == .still)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            TimelineView(schedule) { context in
                let frame = GlobeFrame(
                    camera: scene.camera(at: context.date),
                    size: size,
                    sun: SolarPosition(date: date).direction,
                    style: scene.style,
                    effects: scene.effects.snapshot(at: context.date, tuning: scene.style.effects),
                    weather: scene.style.hasClouds ? weather.frame : nil,
                    petals: scene.style.mesh?.petals == nil ? [] : scene.effects.petalFlights(at: context.date, tuning: scene.style.effects)
                )
                let clouds = CloudPresence(frame: frame, snow: scene.renderer?.snowCover)
                let items = MarkerLayout.items(
                    zones: store.zones,
                    frame: frame,
                    date: date,
                    homeZone: store.homeZone,
                    selection: store.selection,
                    bounds: focusRect.insetBy(dx: 8, dy: 4),
                    surface: frame.style.mesh.flatMap { scene.renderer?.toyMesh?.shapes[$0.shape]?.surface },
                    clouds: clouds,
                    weatherStatus: weather.status,
                    cache: cache
                )
                ZStack(alignment: .topLeading) {
                    GlobeCanvas(frame: frame, renderer: scene.renderer, isReady: scene.isGlobeReady)
                        .gesture(
                            SpatialTapGesture().onEnded { value in
                                select(near: value.location, in: items, frame: frame, clouds: clouds)
                            }
                        )
                    if let drift = scene.style.look.petalDrift, scene.isGlobeReady {
                        PetalDrift(look: drift, isEnabled: !scene.reduceMotion)
                            .frame(width: focusRect.width, height: focusRect.height)
                            .offset(x: focusRect.minX, y: focusRect.minY)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                    MarkerOverlay(items: items, selection: store.selection, isShifted: isShifted) { id in
                        store.toggleSelection(id)
                    }
                    .opacity(scene.isGlobeReady ? 1 : 0)
                    .animation(.easeIn(duration: 0.9), value: scene.isGlobeReady)
                }
                .simultaneousGesture(rotation(frame: frame))
                .simultaneousGesture(zoom)
                .gesture(
                    GlobePressGesture { event in
                        handle(event, frame: frame, items: items)
                    }
                )
            }
            .onChange(of: focusRect, initial: true) {
                scene.fit(to: focusRect, in: size, facing: store.homeLocation)
            }
        }
        .ignoresSafeArea()
        .task(id: scene.cameraMotion) {
            guard let motion = scene.cameraMotion else { return }
            let wait = motion.endDate.timeIntervalSinceNow
            if wait > 0 {
                try? await Task.sleep(for: .seconds(wait))
            }
            guard !Task.isCancelled else { return }
            scene.settle(motion)
        }
        .task(id: scene.effects.nextEnd(tuning: scene.style.effects)) {
            guard let end = scene.effects.nextEnd(tuning: scene.style.effects) else { return }
            let wait = end.timeIntervalSinceNow
            if wait > 0 {
                try? await Task.sleep(for: .seconds(wait))
            }
            guard !Task.isCancelled else { return }
            scene.settleEffects()
        }
        .onChange(of: store.focusRequest) { _, request in
            guard let request else { return }
            scene.focus(on: request.point)
        }
        .onChange(of: store.selection) { _, selection in
            guard let selection, let location = store.zones.first(where: { $0.id == selection })?.location else { return }
            scene.pop(at: location.unitVector)
        }
    }

    private func rotation(frame: GlobeFrame) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard touch.allowsRotation() else { return }
                if dragOrigin == nil {
                    scene.interruptCamera()
                    dragOrigin = scene.camera
                    dragStart = value.translation
                    dragRadius = max(frame.globeRadius, 40)
                }
                guard let dragOrigin else { return }
                let dx = Double(value.translation.width - dragStart.width)
                let dy = Double(value.translation.height - dragStart.height)
                var camera = scene.camera
                camera.yaw = dragOrigin.yaw - dx / dragRadius
                camera.pitch = dragOrigin.pitch + dy / dragRadius
                scene.camera = camera.clamped()
            }
            .onEnded { value in
                guard dragOrigin != nil else { return }
                dragOrigin = nil
                let yawVelocity = -Double(value.velocity.width) / dragRadius
                let pitchVelocity = Double(value.velocity.height) / dragRadius
                scene.coast(yawVelocity: yawVelocity, pitchVelocity: pitchVelocity)
                let axis = frame.right * Double(value.velocity.width) - frame.up * Double(value.velocity.height)
                scene.fling(axis: axis, speed: hypot(yawVelocity, pitchVelocity))
            }
    }

    private var zoom: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if pinchOrigin == nil {
                    scene.interruptCamera()
                    pinchOrigin = scene.camera.distance
                }
                guard let pinchOrigin else { return }
                var camera = scene.camera
                camera.distance = pinchOrigin / Double(value.magnification)
                scene.camera = camera.rubberBanded()
            }
            .onEnded { _ in
                pinchOrigin = nil
                let settled = scene.camera.clamped()
                if settled != scene.camera {
                    scene.fly(to: settled, duration: 0.35)
                }
            }
    }

    private func handle(_ event: GlobePressGesture.Event, frame: GlobeFrame, items: [MarkerItem]) {
        switch event {
        case let .began(location):
            let point = marker(near: location, in: items) == nil ? frame.surfacePoint(at: location, radius: frame.pickRadius) : nil
            touch.begin(at: location, holds: point != nil && scene.allowsSurfaceDrag)
            if let point {
                scene.press(at: point, footprint: footprint(in: frame))
            }
        case let .moved(location):
            apply(touch.move(to: location), at: location, frame: frame)
        case .crowded:
            apply(touch.crowd(), at: .zero, frame: frame)
        case let .ended(location):
            apply(touch.end(at: location), at: location, frame: frame)
        }
    }

    private func apply(_ step: GlobeTouch.Step?, at location: CGPoint, frame: GlobeFrame) {
        switch step {
        case .beginDrag:
            scene.beginSurfaceDrag(at: frame.surfacePoint(at: location, radius: frame.pickRadius), footprint: footprint(in: frame), location: location)
        case .drag:
            scene.dragSurface(to: frame.surfacePoint(at: location, radius: frame.pickRadius), location: location)
        case .endDrag:
            scene.endSurfaceDrag()
        case let .release(moved):
            scene.releasePress(moved: moved)
        case nil:
            break
        }
    }

    private func footprint(in frame: GlobeFrame) -> Double {
        16 / max(frame.globeRadius, 40)
    }

    private func marker(near location: CGPoint, in items: [MarkerItem]) -> MarkerItem? {
        let visible = items.filter { $0.fade > 0.3 }
        if let chip = visible.first(where: { $0.chipFrame?.contains(location) == true }) {
            return chip
        }
        let nearest = visible.min { hypot($0.anchor.x - location.x, $0.anchor.y - location.y) < hypot($1.anchor.x - location.x, $1.anchor.y - location.y) }
        guard let nearest, hypot(nearest.anchor.x - location.x, nearest.anchor.y - location.y) < 32 else { return nil }
        return nearest
    }

    private func select(near location: CGPoint, in items: [MarkerItem], frame: GlobeFrame, clouds: CloudPresence?) {
        if let nearest = marker(near: location, in: items) {
            store.toggleSelection(nearest.id)
            return
        }
        store.selection = nil
        if let clouds, let point = frame.surfacePoint(at: location, radius: frame.pickRadius), clouds.covers(point) {
            scene.pop(at: point)
        }
    }
}
