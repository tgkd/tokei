import SwiftUI

struct SoundRow: View {
    @Environment(SceneModel.self) private var scene
    @Environment(\.sceneStyle) private var style
    @Environment(\.sceneAccent) private var accent

    var body: some View {
        @Bindable var scene = scene
        let interface = style.interface
        let isSilent = style.soundTimbre == nil
        HStack(spacing: 12) {
            Image(systemName: isSilent ? "speaker.slash" : (scene.soundEnabled ? "speaker.wave.2" : "speaker"))
                .font(.system(size: 15, weight: interface.typography.symbolWeight))
                .foregroundStyle(interface.secondaryInk)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 22)
                .accessibilityHidden(true)
            if isSilent {
                Text("Sounds")
                    .font(interface.typography.body(.body))
                    .foregroundStyle(interface.ink)
                Spacer()
                Text("Silent theme")
                    .font(interface.typography.caption(.subheadline))
                    .foregroundStyle(interface.secondaryInk)
            } else {
                Toggle(isOn: $scene.soundEnabled) {
                    Text("Sounds")
                        .font(interface.typography.body(.body))
                        .foregroundStyle(interface.ink)
                }
                .tint(accent)
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: isSilent ? .combine : .contain)
    }
}
