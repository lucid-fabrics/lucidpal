import Combine
import XCTest
@testable import PocketMind

@MainActor
final class AirPodsVoiceCoordinatorTests: XCTestCase {

    // MARK: - Test Properties

    var sut: AirPodsVoiceCoordinator!
    var mockAudioRouteMonitor: MockAudioRouteMonitor!
    var mockSpeechService: MockSpeechService!
    var mockSettings: MockAppSettings!

    // MARK: - Setup & Teardown

    override func setUp() async throws {
        try await super.setUp()
        mockAudioRouteMonitor = MockAudioRouteMonitor()
        mockSpeechService = MockSpeechService()
        mockSettings = MockAppSettings()
        sut = AirPodsVoiceCoordinator(
            audioRouteMonitor: mockAudioRouteMonitor,
            speechService: mockSpeechService,
            settings: mockSettings
        )
    }

    override func tearDown() async throws {
        sut = nil
        mockAudioRouteMonitor = nil
        mockSpeechService = nil
        mockSettings = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInit_setsIsAutoListeningToFalse() {
        XCTAssertFalse(sut.isAutoListening)
    }

    // MARK: - AirPods Connection Tests

    func testStartMonitoring_withAirPodsConnectedAndSettingEnabled_startsAutoVoice() throws {
        // Given: AirPods are connected, setting is enabled, speech is authorized
        mockSettings.airpodsAutoVoiceEnabled = true
        mockAudioRouteMonitor.isAirPodsConnected = true
        mockSpeechService.isAuthorized = true

        // When: Start monitoring
        sut.startMonitoring()

        // Then: Auto-voice should start
        try awaitPublisher(sut.$isAutoListening, timeout: 0.1, equals: true)
        XCTAssertTrue(mockSpeechService.startRecordingCallCount == 1)
    }

    func testStartMonitoring_withAirPodsNotConnected_doesNotStartAutoVoice() {
        // Given: AirPods are NOT connected, setting is enabled
        mockSettings.airpodsAutoVoiceEnabled = true
        mockAudioRouteMonitor.isAirPodsConnected = false
        mockSpeechService.isAuthorized = true

        // When: Start monitoring
        sut.startMonitoring()

        // Then: Auto-voice should NOT start
        XCTAssertFalse(sut.isAutoListening)
        XCTAssertEqual(mockSpeechService.startRecordingCallCount, 0)
    }

    func testStartMonitoring_withSettingDisabled_doesNotStartAutoVoice() {
        // Given: AirPods are connected, setting is DISABLED
        mockSettings.airpodsAutoVoiceEnabled = false
        mockAudioRouteMonitor.isAirPodsConnected = true
        mockSpeechService.isAuthorized = true

        // When: Start monitoring
        sut.startMonitoring()

        // Then: Auto-voice should NOT start
        XCTAssertFalse(sut.isAutoListening)
        XCTAssertEqual(mockSpeechService.startRecordingCallCount, 0)
    }

    func testStopMonitoring_stopsAutoVoice() throws {
        // Given: Auto-voice is active
        mockSettings.airpodsAutoVoiceEnabled = true
        mockAudioRouteMonitor.isAirPodsConnected = true
        mockSpeechService.isAuthorized = true
        sut.startMonitoring()
        try awaitPublisher(sut.$isAutoListening, timeout: 0.1, equals: true)

        // When: Stop monitoring
        sut.stopMonitoring()

        // Then: Auto-voice should stop
        XCTAssertFalse(sut.isAutoListening)
        XCTAssertEqual(mockSpeechService.stopRecordingCallCount, 1)
    }

    // MARK: - Helper Methods

    private func awaitPublisher<T: Equatable>(
        _ publisher: Published<T>.Publisher,
        timeout: TimeInterval,
        equals expectedValue: T
    ) throws {
        let expectation = XCTestExpectation(description: "Publisher emits expected value")
        var cancellable: AnyCancellable?

        cancellable = publisher
            .sink { value in
                if value == expectedValue {
                    expectation.fulfill()
                    cancellable?.cancel()
                }
            }

        wait(for: [expectation], timeout: timeout)
    }
}

// MARK: - Mock AudioRouteMonitor

@MainActor
final class MockAudioRouteMonitor: ObservableObject {
    @Published var isAirPodsConnected = false
    @Published var isHomePodConnected = false
    @Published var currentAudioRoute = ""
}
