import SwiftUI
import UIKit

struct GlobePressGesture: UIGestureRecognizerRepresentable {
    enum Event {
        case began(CGPoint)
        case moved(CGPoint)
        case crowded
        case ended(CGPoint)
    }

    let onEvent: (Event) -> Void

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = 0
        recognizer.allowableMovement = .greatestFiniteMagnitude
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let location = context.converter.localLocation
        switch recognizer.state {
        case .began:
            onEvent(.began(location))
        case .changed:
            onEvent(recognizer.numberOfTouches > 1 ? .crowded : .moved(location))
        case .ended, .cancelled:
            onEvent(.ended(location))
        default:
            break
        }
    }
}
