@testable import PocketMind

@MainActor
final class MockHapticService: HapticServiceProtocol {
    private(set) var impactCalled = false
    private(set) var lastImpactStyle: HapticStyle?
    private(set) var notifySuccessCalled = false
    private(set) var notifyErrorCalled = false
    private(set) var selectionTickCalled = false

    func impact(_ style: HapticStyle) {
        impactCalled = true
        lastImpactStyle = style
    }

    func notifySuccess() {
        notifySuccessCalled = true
    }

    func notifyError() {
        notifyErrorCalled = true
    }

    func selectionTick() {
        selectionTickCalled = true
    }
}
