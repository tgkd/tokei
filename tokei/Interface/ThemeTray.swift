import SwiftUI

struct ThemeTray: View {
    @Environment(SceneModel.self) private var scene
    @Environment(\.sceneStyle) private var style
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let land: CGImage?
    let onClose: () -> Void

    var body: some View {
        let interface = style.interface
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Theme")
                    .font(interface.typography.title(.headline))
                    .foregroundStyle(interface.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: interface.typography.symbolWeight))
                        .foregroundStyle(interface.secondaryInk)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(PressScaleButtonStyle(scale: 0.85))
                .accessibilityLabel("Close themes")
            }
            .padding(.leading, 20)
            .padding(.trailing, 8)
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 14) {
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
                    .padding(.vertical, 10)
                    .scrollTargetLayout()
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned)
                .contentMargins(.horizontal, 18, for: .scrollContent)
                .onAppear {
                    proxy.scrollTo(scene.style, anchor: .center)
                }
            }
            SoundRow()
                .padding(.horizontal, 20)
        }
        .padding(.top, 6)
        .padding(.bottom, 10)
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
