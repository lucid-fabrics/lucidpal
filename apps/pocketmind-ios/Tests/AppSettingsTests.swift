import XCTest

@testable import PocketMind

@MainActor
final class AppSettingsTests: XCTestCase {
    var settings: AppSettings!

    override func setUp() {
        super.setUp()
        settings = AppSettings()
    }

    private static let allKeys = [
        "calendarAccessEnabled", "selectedModelID", "hasCompletedOnboarding",
        "thinkingEnabled", "defaultCalendarIdentifier", "speechAutoSendEnabled",
        "voiceAutoStartEnabled", "contextSize",
    ]

    override func tearDown() {
        for key in Self.allKeys { UserDefaults.standard.removeObject(forKey: key) }
        super.tearDown()
    }

    func testSelectedModelReturnsQwen3_5_2BByID() {
        settings.selectedModelID = ModelInfo.qwen3_5_2B.id
        XCTAssertEqual(settings.selectedModel, .qwen3_5_2B)
    }

    func testSelectedModelReturnsQwen3_5_4BByID() {
        settings.selectedModelID = ModelInfo.qwen3_5_4B.id
        XCTAssertEqual(settings.selectedModel, .qwen3_5_4B)
    }

    func testSelectedModelFallsBackToQwen3_5_2BForUnknownID() {
        settings.selectedModelID = "nonexistent-model-id"
        XCTAssertEqual(settings.selectedModel, .qwen3_5_2B)
    }

    func testDeviceRAMGBIsPositive() {
        XCTAssertGreaterThan(settings.deviceRAMGB, 0)
    }

    // MARK: - Default values

    func testDefaultCalendarAccessEnabledIsFalse() {
        UserDefaults.standard.removeObject(forKey: "calendarAccessEnabled")
        XCTAssertFalse(AppSettings().calendarAccessEnabled)
    }

    func testDefaultThinkingEnabledIsTrue() {
        UserDefaults.standard.removeObject(forKey: "thinkingEnabled")
        XCTAssertTrue(AppSettings().thinkingEnabled)
    }

    func testDefaultSpeechAutoSendEnabledIsTrue() {
        UserDefaults.standard.removeObject(forKey: "speechAutoSendEnabled")
        XCTAssertTrue(AppSettings().speechAutoSendEnabled)
    }

    func testDefaultHasCompletedOnboardingIsFalse() {
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
        XCTAssertFalse(AppSettings().hasCompletedOnboarding)
    }

    func testDefaultCalendarIdentifierIsEmpty() {
        UserDefaults.standard.removeObject(forKey: "defaultCalendarIdentifier")
        XCTAssertEqual(AppSettings().defaultCalendarIdentifier, "")
    }

    func testDefaultContextSizeIs4096() {
        UserDefaults.standard.removeObject(forKey: "contextSize")
        XCTAssertEqual(AppSettings().contextSize, 4096)
    }

    func testContextSizePersistsToUserDefaults() {
        settings.contextSize = 8192
        XCTAssertEqual(AppSettings().contextSize, 8192)
    }

    func testMaxContextSizeIsAtLeast4096() {
        XCTAssertGreaterThanOrEqual(settings.maxContextSize, 4096)
    }

    func testDefaultVoiceAutoStartEnabledIsFalse() {
        UserDefaults.standard.removeObject(forKey: "voiceAutoStartEnabled")
        XCTAssertFalse(AppSettings().voiceAutoStartEnabled)
    }
}
