import SwiftUI

struct SwatchLook: Equatable {
    enum Finish: Equatable {
        case atmosphere
        case gloss
        case frost
        case chrome
        case paper
        case clouds
    }

    var ocean: Color
    var land: Color
    var night: Color
    var rim: Color
    var finish: Finish
}
