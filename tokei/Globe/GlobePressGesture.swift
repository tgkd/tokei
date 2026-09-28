import SwiftUI
import UIKit

struct GlobePressGesture: UIGestureRecognizerRepresentable {
    let onPress: (CGPoint) -> Void
    let onRelease: (_ moved: Bool) -> Void

    private static let movementTolerance = 10.0

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var origin: CGPoint?

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
            context.coordinator.origin = location
            onPress(location)
        case .ended, .cancelled:
            let origin = context.coordinator.origin ?? location
            context.coordinator.origin = nil
            onRelease(hypot(location.x - origin.x, location.y - origin.y) > Self.movementTolerance)
        default:
            break
        }
    }
}
