import XCTest
@testable import PocketMind

@MainActor
final class SettingsViewModelTests: XCTestCase {
    var settings: AppSettingsProtocol!
    var mockCalendar: MockCalendarService!
    var viewModel: SettingsViewModel!

    private static let allKeys = ["voiceAutoStartEnabled", "speechAutoSendEnabled"]

    override func setUp() async throws {
        try await super.setUp()
        for key in Self.allKeys { UserDefaults.standard.removeObject(forKey: key) }
        settings = MockAppSettings()
        mockCalendar = MockCalendarService()
        viewModel = SettingsViewModel(settings: settings, calendarService: mockCalendar)
    }

    override func tearDown() {
        for key in Self.allKeys { UserDefaults.standard.removeObject(forKey: key) }
        super.tearDown()
    }

    func testInitSetsCalendarAuthStatus() {
        XCTAssertEqual(viewModel.calendarAuthStatus, .fullAccess)
    }

    func testIsCalendarAuthorizedReflectsService() {
        mockCalendar.isAuthorized = true
        XCTAssertTrue(viewModel.isCalendarAuthorized)
        mockCalendar.isAuthorized = false
        XCTAssertFalse(viewModel.isCalendarAuthorized)
    }

    func testRequestCalendarAccessGrantedUpdatesSettings() async throws {
        mockCalendar.requestAccessResult = true
        await viewModel.requestCalendarAccess()
        XCTAssertTrue(settings.calendarAccessEnabled)
        XCTAssertEqual(viewModel.calendarAuthStatus, .fullAccess)
    }

    func testRequestCalendarAccessDeniedDisablesToggle() async throws {
        mockCalendar.requestAccessResult = false
        await viewModel.requestCalendarAccess()
        XCTAssertFalse(settings.calendarAccessEnabled)
        XCTAssertEqual(viewModel.calendarAuthStatus, .denied)
    }

    func testAvailableCalendarsFromService() {
        let calendars = viewModel.availableCalendars
        XCTAssertFalse(calendars.isEmpty)
        XCTAssertEqual(calendars.first?.title, "Calendar")
    }

    func testSetDefaultCalendarStoresID() {
        viewModel.setDefaultCalendar(id: "cal-123")
        XCTAssertEqual(settings.defaultCalendarIdentifier, "cal-123")
    }

    func testSetDefaultCalendarNilResetsToEmpty() {
        viewModel.setDefaultCalendar(id: nil)
        XCTAssertEqual(settings.defaultCalendarIdentifier, "")
    }

    func testSelectModelUpdatesSettingsID() {
        viewModel.selectModel(.qwen3_5_2B)
        XCTAssertEqual(settings.selectedModelID, ModelInfo.qwen3_5_2B.id)
    }

    func testAvailableModelsNotEmpty() {
        XCTAssertFalse(viewModel.availableModels.isEmpty)
    }

    func testSetVoiceAutoStartTrueEnablesSpeechAutoSend() {
        settings.speechAutoSendEnabled = false
        viewModel.setVoiceAutoStart(true)
        XCTAssertTrue(settings.voiceAutoStartEnabled)
        XCTAssertTrue(settings.speechAutoSendEnabled)
    }

    func testSetVoiceAutoStartFalseDoesNotChangeSpeechAutoSend() {
        settings.speechAutoSendEnabled = false
        viewModel.setVoiceAutoStart(false)
        XCTAssertFalse(settings.voiceAutoStartEnabled)
        XCTAssertFalse(settings.speechAutoSendEnabled)
    }

    func testSetVoiceAutoStartFalsePreservesExistingSpeechAutoSend() {
        settings.speechAutoSendEnabled = true
        viewModel.setVoiceAutoStart(false)
        XCTAssertFalse(settings.voiceAutoStartEnabled)
        XCTAssertTrue(settings.speechAutoSendEnabled)
    }
}
