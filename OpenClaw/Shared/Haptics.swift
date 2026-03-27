import UIKit

/// Centralized haptic feedback triggers.
@MainActor
struct Haptics {
    static let shared = Haptics()

    private let notification = UINotificationFeedbackGenerator()
    private let impact = UIImpactFeedbackGenerator(style: .light)

    func success() {
        notification.notificationOccurred(.success)
    }

    func error() {
        notification.notificationOccurred(.error)
    }

    func refreshComplete() {
        impact.impactOccurred()
    }
}
