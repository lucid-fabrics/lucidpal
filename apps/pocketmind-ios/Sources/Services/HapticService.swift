import UIKit

/// Thin UIKit wrapper for haptic feedback.
/// Centralises the UIKit import so ViewModels stay free of platform UI frameworks.
enum HapticService {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func notifySuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
