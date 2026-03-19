import UIKit
@testable import PocketMind

@MainActor
final class MockHapticService: HapticServiceProtocol {
    private(set) var impactCalled = false
    private(set) var lastImpactStyle: UIImpactFeedbackGenerator.FeedbackStyle?
    private(set) var notifySuccessCalled = false

    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        impactCalled = true
        lastImpactStyle = style
    }

    func notifySuccess() {
        notifySuccessCalled = true
    }
}
