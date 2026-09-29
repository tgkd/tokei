import SwiftUI

struct ThemeTray: View {
    @Environment(SceneModel.self) private var scene
    @Environment(\.sceneStyle) private var style
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let land: CGImage?

    var body: some View {
        let interface = style.interface
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 3) {
                        ForEach(SceneStyle.allCases) { candidate in
                            Button {
                                choose(candidate, proxy: proxy)
                            } label: {
                                ThemeTile(style: candidate, land: land, isSelected: candidate == scene.style)
                            }
                            .buttonStyle(PressScaleButtonStyle())
                            .id(candidate)
                            .accessibilityLabel(candidate.displayName)
                            .accessibilityAddTraits(candidate == scene.style ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.leading, 8, for: .scrollContent)
                .contentMargins(.trailing, 2, for: .scrollContent)
                .onAppear {
                    proxy.scrollTo(scene.style, anchor: .center)
                }
            }
            SoundToggle()
                .padding(.trailing, 6)
        }
        .padding(.vertical, 2)
        .surface(interface.panel, in: .rect(cornerRadius: interface.panelCorner, style: .continuous))
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .sensoryFeedback(trigger: scene.style) { _, next in
            next.usesMesh ? nil : .selection
        }
    }

    private func choose(_ candidate: SceneStyle, proxy: ScrollViewProxy) {
        guard candidate != scene.style else { return }
        withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : .smooth(duration: 0.35)) {
            scene.style = candidate
            proxy.scrollTo(candidate, anchor: .center)
        }
    }
}
