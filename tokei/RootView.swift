import SwiftUI

struct RootView: View {
    @Environment(ClockStore.self) private var store
    @Environment(SceneModel.self) private var scene
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showsList = false
    @State private var showsThemes = false
    @State private var detent: PresentationDetent = .medium
    @State private var panelHeight: CGFloat = 132
    @State private var landSilhouette: CGImage?

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
                        bottomPanel(shift: shift)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { panelHeight = $0 }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 2)
                            .opacity(showsList ? 0 : 1)
                            .allowsHitTesting(!showsList)
                    }
                }
            }
        }
        .background(scene.style.backdrop.ignoresSafeArea())
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
        .task(id: showsThemes) {
            guard showsThemes, landSilhouette == nil else { return }
            landSilhouette = await Task.detached(priority: .userInitiated) {
                LandSilhouette.render(latitude: 18, longitude: 12)
            }.value
        }
        .onChange(of: scenePhase) { _, phase in
            scene.isForeground = phase == .active
            if phase == .active {
                store.reload()
                scene.syncShiftFromStorage()
            }
        }
        .onChange(of: reduceMotion, initial: true) { _, reduceMotion in
            scene.reduceMotion = reduceMotion
        }
        .sensoryFeedback(trigger: scene.cue) { _, cue in
            cue?.haptic
        }
        .environment(\.sceneAccent, scene.style.accent)
        .environment(\.sceneStyle, scene.style)
        .preferredColorScheme(scene.style.interface.colorScheme)
    }

    private var topBar: some View {
        HStack {
            ThemeIconButton(systemName: "location.fill", label: "Show my time zone") {
                store.focusHome()
            }
            Spacer()
            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    ThemeIconButton(
                        systemName: showsThemes ? "paintpalette.fill" : "paintpalette",
                        label: "Theme",
                        value: scene.style.displayName,
                        isActive: showsThemes
                    ) {
                        setThemes(visible: !showsThemes)
                    }
                    ThemeIconButton(systemName: "list.bullet", label: "Cities") {
                        setThemes(visible: false)
                        detent = .medium
                        showsList = true
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    private func bottomPanel(shift: Double) -> some View {
        ZStack(alignment: .bottom) {
            if showsThemes {
                ThemeTray(land: landSilhouette) {
                    setThemes(visible: false)
                }
                .transition(panelTransition)
            } else {
                ScrubberPanel(now: store.now, shift: shift, homeZone: store.homeZone)
                    .transition(panelTransition)
            }
        }
    }

    private var panelTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .scale(scale: 0.9, anchor: .bottom).combined(with: .opacity),
            removal: .scale(scale: 0.96, anchor: .bottom).combined(with: .opacity)
        )
    }

    private func setThemes(visible: Bool) {
        guard visible != showsThemes else { return }
        if visible {
            showsList = false
        }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(duration: 0.42, bounce: 0.28)) {
            showsThemes = visible
        }
    }

    private func focusRect(size: CGSize, insets: EdgeInsets) -> CGRect {
        let fullHeight = size.height + insets.top + insets.bottom
        let fullWidth = size.width + insets.leading + insets.trailing
        let top = insets.top + 56
        let bottom = showsList ? fullHeight * 0.5 : insets.bottom + panelHeight + 6
        return CGRect(x: 0, y: top, width: fullWidth, height: max(fullHeight - top - bottom, 160))
    }
}
