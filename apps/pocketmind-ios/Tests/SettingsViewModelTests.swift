import XCTest
@testable import PocketMind

@MainActor
final class SettingsViewModelTests: XCTestCase {
    var settings: AppSettings!
    var mockCalendar: MockCalendarService!
    var viewModel: SettingsViewModel!

    override func setUp() {
        super.setUp()
        settings = AppSettings()
        mockCalendar = MockCalendarService()
        viewModel = SettingsViewModel(settings: settings, calendarService: mockCalendar)
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
        viewModel.selectModel(.qwen3_1B7)
        XCTAssertEqual(settings.selectedModelID, ModelInfo.qwen3_1B7.id)
    }

    func testAvailableModelsNotEmpty() {
        XCTAssertFalse(viewModel.availableModels.isEmpty)
    }
}
