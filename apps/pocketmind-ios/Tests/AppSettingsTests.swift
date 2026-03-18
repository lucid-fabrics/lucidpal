import XCTest
@testable import PocketMind

@MainActor
final class AppSettingsTests: XCTestCase {
    var settings: AppSettings!

    override func setUp() {
        super.setUp()
        settings = AppSettings()
    }

    override func tearDown() {
        // Remove keys written during tests to avoid polluting UserDefaults.standard
        UserDefaults.standard.removeObject(forKey: "selectedModelID")
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
}
