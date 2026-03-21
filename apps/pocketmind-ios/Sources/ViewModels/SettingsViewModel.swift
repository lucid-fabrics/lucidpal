import Combine
import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var calendarAuthStatus: CalendarAuthorizationStatus = .notDetermined
    @Published var availableModels: [ModelInfo] = []

    let settings: any AppSettingsProtocol
    let calendarService: any CalendarServiceProtocol

    init(settings: any AppSettingsProtocol, calendarService: any CalendarServiceProtocol) {
        self.settings = settings
        self.calendarService = calendarService
        self.calendarAuthStatus = calendarService.authorizationStatus
        self.availableModels = ModelInfo.available(physicalRAMGB: settings.deviceRAMGB)

        if availableModels.isEmpty {
            availableModels = [.qwen3_5_2B]
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

    func setVoiceAutoStart(_ enabled: Bool) {
        settings.voiceAutoStartEnabled = enabled
        if enabled { settings.speechAutoSendEnabled = true }
    }
}
