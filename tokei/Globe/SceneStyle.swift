import SwiftUI

enum SceneStyle: String, CaseIterable, Identifiable {
    case realistic
    case toy
    case ice
    case chrome
    case paper
    case weather
    case sakura
    case magma
    case abyss
    case pixel

    private static let defaultsKey = "scene_style"

    var id: String {
        rawValue
    }

    var look: SceneLook {
        switch self {
        case .realistic: .realistic
        case .toy: .toy
        case .ice: .ice
        case .chrome: .chrome
        case .paper: .paper
        case .weather: .weather
        case .sakura: .sakura
        case .magma: .magma
        case .abyss: .abyss
        case .pixel: .pixel
        }
    }

    var displayName: String {
        look.name
    }

    var mesh: MeshLook? {
        look.mesh
    }

    var usesMesh: Bool {
        look.mesh != nil
    }

    var hasClouds: Bool {
        look.mesh?.clouds != nil
    }

    var soundTimbre: SoundTimbre? {
        look.sound
    }

    var backdrop: Color {
        look.backdropColor
    }

    var accent: Color {
        look.accent
    }

    var effects: EffectTuning {
        look.effects
    }

    static func load() -> SceneStyle {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(SceneStyle.init(rawValue:)) ?? .realistic
    }

    func save() {
        UserDefaults.standard.set(rawValue, forKey: Self.defaultsKey)
    }
}

extension EnvironmentValues {
    @Entry var sceneAccent: Color = .sunlight
}
