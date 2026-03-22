import XCTest
import UIKit
@testable import PocketMind

/// Tests the HapticServiceProtocol contract using MockHapticService.
@MainActor
final class HapticServiceProtocolTests: XCTestCase {
    var haptic: MockHapticService!

    override func setUp() {
        super.setUp()
        haptic = MockHapticService()
    }

    func testImpactRecordsCall() {
        haptic.impact(.light)
        XCTAssertTrue(haptic.impactCalled)
    }

    func testImpactRecordsStyle() {
        haptic.impact(.heavy)
        XCTAssertEqual(haptic.lastImpactStyle, .heavy)
    }

    func testNotifySuccessRecordsCall() {
        haptic.notifySuccess()
        XCTAssertTrue(haptic.notifySuccessCalled)
    }

    func testImpactAndNotifyAreIndependent() {
        haptic.impact(.medium)
        XCTAssertTrue(haptic.impactCalled)
        XCTAssertFalse(haptic.notifySuccessCalled)
    }

    func testMultipleImpactCallsRecordLastStyle() {
        haptic.impact(.light)
        haptic.impact(.heavy)
        XCTAssertEqual(haptic.lastImpactStyle, .heavy)
    }
}
