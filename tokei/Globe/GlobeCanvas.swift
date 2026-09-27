import SwiftUI

struct GlobeCanvas: UIViewRepresentable {
    let frame: GlobeFrame
    let renderer: GlobeRenderer?
    let isReady: Bool

    func makeUIView(context: Context) -> GlobeLayerView {
        let view = GlobeLayerView(frame: .zero)
        view.renderer = renderer
        view.frameModel = frame
        return view
    }

    func updateUIView(_ view: GlobeLayerView, context: Context) {
        if view.renderer !== renderer {
            view.renderer = renderer
        }
        view.frameModel = frame
        if isReady && !view.hasStartedReveal {
            view.startReveal()
        }
    }
}
