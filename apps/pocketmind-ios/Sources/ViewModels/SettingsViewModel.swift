import Combine
import EventKit
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var calendarAuthStatus: EKAuthorizationStatus = .notDetermined
    @Published var availableModels: [ModelInfo] = []

    let settings: AppSettings
    let calendarService: CalendarService

    init(settings: AppSettings, calendarService: CalendarService) {
        self.settings = settings
        self.calendarService = calendarService
        self.calendarAuthStatus = calendarService.authorizationStatus
        self.availableModels = ModelInfo.available(physicalRAMGB: settings.deviceRAMGB)

        if availableModels.isEmpty {
            availableModels = [.qwen3_1B7]
        }
    }

    var isCalendarAuthorized: Bool {
        calendarService.isAuthorized
    }

    var availableCalendars: [CalendarInfo] {
        calendarService.writableCalendars()
    }

    func setDefaultCalendar(id: String?) {
        settings.defaultCalendarIdentifier = id ?? ""
    }

    func requestCalendarAccess() async {
        _ = await calendarService.requestAccess()
        calendarAuthStatus = calendarService.authorizationStatus
        settings.calendarAccessEnabled = calendarService.isAuthorized
    }

    func selectModel(_ model: ModelInfo) {
        settings.selectedModelID = model.id
    }
}
