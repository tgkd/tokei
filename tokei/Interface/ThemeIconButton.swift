import SwiftUI

struct ThemeIconButton: View {
    @Environment(\.sceneStyle) private var style

    let systemName: String
    let label: String
    var value: String?
    var isActive = false
    let action: () -> Void

    var body: some View {
        let interface = style.interface
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: interface.typography.symbolWeight))
                .foregroundStyle(isActive ? interface.onAccent : interface.controlInk)
                .embossed(interface.typography.engraved)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .contentShape(.circle)
        }
        .buttonStyle(SurfaceButtonStyle(surface: isActive ? interface.accentSurface : interface.control, shape: Circle()))
        .accessibilityLabel(label)
        .accessibilityValue(value ?? "")
    }
}
