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
    ]

    override func tearDown() {
        for key in Self.allKeys { UserDefaults.standard.removeObject(forKey: key) }
        super.tearDown()
    }

    func testSelectedModelReturnsQwen1B7ByID() {
        settings.selectedModelID = ModelInfo.qwen3_1B7.id
        XCTAssertEqual(settings.selectedModel, .qwen3_1B7)
    }

    func testSelectedModelReturnsQwen4BByID() {
        settings.selectedModelID = ModelInfo.qwen3_4B.id
        XCTAssertEqual(settings.selectedModel, .qwen3_4B)
    }

    func testSelectedModelFallsBackToQwen1B7ForUnknownID() {
        settings.selectedModelID = "nonexistent-model-id"
        XCTAssertEqual(settings.selectedModel, .qwen3_1B7)
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
}
