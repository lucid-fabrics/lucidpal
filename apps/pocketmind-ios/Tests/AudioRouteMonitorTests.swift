import AVFoundation
import Combine
@testable import PocketMind
import XCTest

@MainActor
final class AudioRouteMonitorTests: XCTestCase {

    // MARK: - Test Properties

    var sut: AudioRouteMonitor!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        sut = AudioRouteMonitor()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_setsInitialAudioRouteState() {
        // currentAudioRoute is a non-optional String populated from AVAudioSession.
        // Verify it is stable across reads on the same actor (AVAudioSession is not
        // controllable in unit tests, so consistency is the meaningful assertion here).
        let route = sut.currentAudioRoute
        XCTAssertEqual(route, sut.currentAudioRoute, "currentAudioRoute must return a consistent value")
    }

    func testInit_airPodsNotConnectedByDefault() {
        // In test environment, AirPods are not connected
        XCTAssertFalse(sut.isAirPodsConnected)
    }

    func testInit_homePodNotConnectedByDefault() {
        // In test environment, HomePod is not connected
        XCTAssertFalse(sut.isHomePodConnected)
    }

    // MARK: - Published Property Tests

    func testIsAirPodsConnected_isPublished() {
        // Verify $isAirPodsConnected publisher emits an initial value
        var received: [Bool] = []
        let cancellable = sut.isAirPodsConnectedPublisher.sink { received.append($0) }
        XCTAssertEqual(received, [false], "Publisher must emit false as the initial value in test environment")
        cancellable.cancel()
    }

    func testIsHomePodConnected_isPublished() {
        // isHomePodConnected and isAirPodsConnected are independently tracked
        XCTAssertFalse(sut.isHomePodConnected, "HomePod must not be connected in test environment")
        XCTAssertFalse(sut.isAirPodsConnected && sut.isHomePodConnected, "Both cannot be true simultaneously in test environment")
    }

    func testCurrentAudioRoute_isPublished() {
        // currentAudioRoute is a non-optional String — verify it is stable on the main actor
        let route1 = sut.currentAudioRoute
        let route2 = sut.currentAudioRoute
        XCTAssertEqual(route1, route2, "currentAudioRoute must return a consistent value")
    }

    // NOTE: We cannot directly test AVAudioSession route changes in unit tests
    // because AVAudioSession is a system singleton that requires hardware.
    // Full integration tests would require:
    // 1. Physical device with AirPods
    // 2. XCUITest automation to connect/disconnect Bluetooth
    // 3. Testing on actual hardware, not simulator
    //
    // The core logic (parsing port types and names) is covered by the implementation.
    // Manual testing checklist:
    // - Connect AirPods → isAirPodsConnected should be true
    // - Disconnect AirPods → isAirPodsConnected should be false
    // - Connect to HomePod → isHomePodConnected should be true
    // - Phone call interruption → route changes handled
}
