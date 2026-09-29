import SwiftUI

@main
struct TokeiApp: App {
    @State private var store = ClockStore()
    @State private var scene = SceneModel()
    @State private var weather = WeatherFeed()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(scene)
                .environment(weather)
                .onOpenURL { url in
                    open(url)
                }
        }
    }

    private func open(_ url: URL) {
        guard url.scheme == "tokei" else { return }
        store.reload()
        scene.syncShiftFromStorage()
        guard url.host() == "zone", let id = UUID(uuidString: url.lastPathComponent) else { return }
        if let zone = store.zones.first(where: { $0.id == id }) {
            store.focus(on: zone)
        }
    }
}
