import SwiftUI

struct SoundToggle: View {
    @Environment(SceneModel.self) private var scene
    @Environment(\.sceneStyle) private var style

    var body: some View {
        let interface = style.interface
        let isSilent = style.soundTimbre == nil
        let isOn = scene.soundEnabled && !isSilent
        Button {
            scene.soundEnabled.toggle()
        } label: {
            Image(systemName: isOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 15, weight: interface.typography.symbolWeight))
                .foregroundStyle(isOn ? interface.ink : interface.secondaryInk)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.85))
        .disabled(isSilent)
        .opacity(isSilent ? 0.45 : 1)
        .accessibilityLabel("Sounds")
        .accessibilityValue(isSilent ? "Silent theme" : (scene.soundEnabled ? "On" : "Off"))
    }
}
