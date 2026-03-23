import UIKit

// MARK: - Domain type

/// Platform-agnostic haptic intensity — keeps UIKit out of ViewModel call sites.
enum HapticStyle {
    case light, medium, heavy
}

// MARK: - Protocol

@MainActor
protocol HapticServiceProtocol {
    func impact(_ style: HapticStyle)
    func notifySuccess()
}

// MARK: - Implementation

/// Thin UIKit wrapper for haptic feedback.
/// Centralises the UIKit import so ViewModels stay free of platform UI frameworks.
@MainActor
final class HapticService: HapticServiceProtocol {
    func impact(_ style: HapticStyle) {
        let uiStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light:  uiStyle = .light
        case .medium: uiStyle = .medium
        case .heavy:  uiStyle = .heavy
        }
        UIImpactFeedbackGenerator(style: uiStyle).impactOccurred()
    }

    func notifySuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
