import UIKit

// MARK: - Protocol

@MainActor
protocol HapticServiceProtocol {
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle)
    func notifySuccess()
}

// MARK: - Implementation

/// Thin UIKit wrapper for haptic feedback.
/// Centralises the UIKit import so ViewModels stay free of platform UI frameworks.
@MainActor
final class HapticService: HapticServiceProtocol {
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func notifySuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
