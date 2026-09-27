import SwiftUI

struct GlobeScene: View {
    @Environment(SceneModel.self) private var scene
    @Environment(ClockStore.self) private var store

    let date: Date
    let isShifted: Bool
    let focusRect: CGRect

    @State private var cache = MarkerLayoutCache()
    @State private var dragOrigin: OrbitCamera?
    @State private var dragStart: CGSize = .zero
    @State private var dragRadius: Double = 1
    @State private var pinchOrigin: Double?

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            TimelineView(.animation(minimumInterval: nil, paused: scene.cameraMotion == nil)) { context in
                let frame = GlobeFrame(
                    camera: scene.camera(at: context.date),
                    size: size,
                    sun: SolarPosition(date: date).direction
                )
                let items = MarkerLayout.items(
                    zones: store.zones,
                    frame: frame,
                    date: date,
                    selection: store.selection,
                    bounds: focusRect.insetBy(dx: 8, dy: 4),
                    cache: cache
                )
                ZStack(alignment: .topLeading) {
                    GlobeCanvas(frame: frame, renderer: scene.renderer, isReady: scene.isGlobeReady)
                        .gesture(
                            SpatialTapGesture().onEnded { value in
                                select(near: value.location, in: items)
                            }
                        )
                    MarkerOverlay(items: items, selection: store.selection, isShifted: isShifted) { id in
                        store.toggleSelection(id)
                    }
                    .opacity(scene.isGlobeReady ? 1 : 0)
                    .animation(.easeIn(duration: 0.9), value: scene.isGlobeReady)
                }
                .simultaneousGesture(rotation(frame: frame))
                .simultaneousGesture(zoom)
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
        .onChange(of: store.focusRequest) { _, request in
            guard let request else { return }
            scene.fly(to: scene.destination.facing(request.point))
        }
    }

    private func rotation(frame: GlobeFrame) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
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
                dragOrigin = nil
                let yawVelocity = -Double(value.velocity.width) / dragRadius
                let pitchVelocity = Double(value.velocity.height) / dragRadius
                scene.coast(yawVelocity: yawVelocity, pitchVelocity: pitchVelocity)
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

    private func select(near location: CGPoint, in items: [MarkerItem]) {
        let nearest = items
            .filter { $0.fade > 0.3 }
            .min { hypot($0.anchor.x - location.x, $0.anchor.y - location.y) < hypot($1.anchor.x - location.x, $1.anchor.y - location.y) }
        if let nearest, hypot(nearest.anchor.x - location.x, nearest.anchor.y - location.y) < 32 {
            store.toggleSelection(nearest.id)
        } else {
            store.selection = nil
        }
    }
}
