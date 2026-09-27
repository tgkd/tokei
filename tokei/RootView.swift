import SwiftUI

struct RootView: View {
    @Environment(ClockStore.self) private var store
    @Environment(SceneModel.self) private var scene
    @Environment(\.scenePhase) private var scenePhase

    @State private var showsList = false
    @State private var detent: PresentationDetent = .medium
    @State private var panelHeight: CGFloat = 132

    var body: some View {
        GeometryReader { proxy in
            let rect = focusRect(size: proxy.size, insets: proxy.safeAreaInsets)
            TimelineView(.animation(minimumInterval: nil, paused: scene.shiftGlide == nil)) { context in
                let shift = scene.shift(at: context.date)
                let date = store.now.addingTimeInterval(shift * 60)
                ZStack {
                    GlobeScene(date: date, isShifted: abs(shift) >= 0.5, focusRect: rect)
                    VStack(spacing: 0) {
                        topBar
                        Spacer(minLength: 0)
                        ScrubberPanel(now: store.now, shift: shift)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { panelHeight = $0 }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 2)
                            .opacity(showsList ? 0 : 1)
                            .allowsHitTesting(!showsList)
                    }
                }
            }
        }
        .background(Color.space.ignoresSafeArea())
        .sheet(isPresented: $showsList) {
            ZoneListSheet(date: store.now.addingTimeInterval(scene.shift * 60), isShifted: scene.committedShift != 0)
                .presentationDetents([.medium, .large], selection: $detent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationContentInteraction(.scrolls)
        }
        .animation(.easeInOut(duration: 0.25), value: showsList)
        .task {
            await scene.prepareGlobe()
        }
        .task {
            await store.runClock()
        }
        .task(id: scene.shiftGlide) {
            guard let glide = scene.shiftGlide else { return }
            let wait = glide.endDate.timeIntervalSinceNow
            if wait > 0 {
                try? await Task.sleep(for: .seconds(wait))
            }
            guard !Task.isCancelled else { return }
            scene.settle(glide)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                store.reload()
                scene.syncShiftFromStorage()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var topBar: some View {
        HStack {
            GlassIconButton(systemName: "location.fill", label: "Show my time zone") {
                store.focusHome()
            }
            Spacer()
            GlassIconButton(systemName: "list.bullet", label: "Cities") {
                detent = .medium
                showsList = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private func focusRect(size: CGSize, insets: EdgeInsets) -> CGRect {
        let fullHeight = size.height + insets.top + insets.bottom
        let fullWidth = size.width + insets.leading + insets.trailing
        let top = insets.top + 56
        let bottom = showsList ? fullHeight * 0.5 : insets.bottom + panelHeight + 6
        return CGRect(x: 0, y: top, width: fullWidth, height: max(fullHeight - top - bottom, 160))
    }
}
