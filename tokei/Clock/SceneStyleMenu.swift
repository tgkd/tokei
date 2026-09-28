import SwiftUI

struct SceneStyleMenu: View {
    @Environment(SceneModel.self) private var scene

    var body: some View {
        @Bindable var scene = scene
        Menu {
            Picker("Scene style", selection: $scene.style) {
                ForEach(SceneStyle.allCases) { style in
                    Text(style.displayName).tag(style)
                }
            }
            if scene.style.soundTimbre != nil {
                Toggle("Sounds", isOn: $scene.soundEnabled)
            }
        } label: {
            Image(systemName: "paintpalette")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("Scene style")
        .accessibilityValue(scene.style.displayName)
    }
}
