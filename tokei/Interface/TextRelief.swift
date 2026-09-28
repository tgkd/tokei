import SwiftUI

struct TextRelief: ViewModifier {
    enum Kind {
        case flat
        case engraved
        case embossed
    }

    let kind: Kind

    func body(content: Content) -> some View {
        switch kind {
        case .flat:
            content
        case .engraved:
            content
                .shadow(color: .black.opacity(0.85), radius: 0, x: 0, y: -1)
                .shadow(color: .white.opacity(0.14), radius: 0, x: 0, y: 1)
        case .embossed:
            content
                .shadow(color: .white.opacity(0.5), radius: 0, x: 0, y: 1)
        }
    }
}

extension View {
    func engraved(_ isEngraved: Bool) -> some View {
        modifier(TextRelief(kind: isEngraved ? .engraved : .flat))
    }

    func embossed(_ isEmbossed: Bool) -> some View {
        modifier(TextRelief(kind: isEmbossed ? .embossed : .flat))
    }
}
