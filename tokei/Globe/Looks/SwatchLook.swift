import SwiftUI

struct SwatchLook: Equatable {
    enum Finish: Equatable {
        case atmosphere
        case gloss
        case frost
        case chrome
        case paper
        case clouds
        case blossom
        case ember
        case glow
        case pixel
        case enamel
        case raked
        case tiles
        case yarn
    }

    var ocean: Color
    var land: Color
    var night: Color
    var rim: Color
    var finish: Finish
}
