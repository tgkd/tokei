import SwiftUI

enum SceneStyle: String, CaseIterable, Identifiable {
    case realistic
    case toy
    case ice

    private static let defaultsKey = "scene_style"

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .realistic: "Realistic"
        case .toy: "Toy"
        case .ice: "Ice"
        }
    }

    var toyPalette: ToyPalette? {
        switch self {
        case .realistic: nil
        case .toy: .standard
        case .ice: .ice
        }
    }

    var toyMaterial: ToyMaterial {
        switch self {
        case .realistic, .toy: .standard
        case .ice: .ice
        }
    }

    var toyShape: ToyShape {
        switch self {
        case .realistic, .toy: .puffy
        case .ice: .glacier
        }
    }

    var usesMesh: Bool {
        toyPalette != nil
    }

    var soundTimbre: SoundTimbre? {
        switch self {
        case .realistic: nil
        case .toy: .soft
        case .ice: .glass
        }
    }

    var backdrop: Color {
        toyPalette?.backdropColor ?? .space
    }

    var accent: Color {
        switch self {
        case .realistic, .toy: .sunlight
        case .ice: Color(red: 0.62, green: 0.745, blue: 0.867)
        }
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
