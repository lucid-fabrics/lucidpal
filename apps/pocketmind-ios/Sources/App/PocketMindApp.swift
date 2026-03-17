import SwiftUI

@main
struct PocketMindApp: App {
    // Services — created once for the app lifetime
    private let settings = AppSettings()
    private let llmService = LLMService()
    private let calendarService = CalendarService()

    // ViewModels wired to real services
    private let chatViewModel: ChatViewModel
    private let settingsViewModel: SettingsViewModel
    private let downloadViewModel: ModelDownloadViewModel

    init() {
        chatViewModel = ChatViewModel(
            llmService: llmService,
            calendarService: calendarService,
            settings: settings
        )
        settingsViewModel = SettingsViewModel(
            settings: settings,
            calendarService: calendarService
        )
        downloadViewModel = ModelDownloadViewModel(
            llmService: llmService,
            settings: settings
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView(
                settings: settings,
                llmService: llmService,
                chatViewModel: chatViewModel,
                settingsViewModel: settingsViewModel,
                downloadViewModel: downloadViewModel
            )
        }
    }
}

private struct RootView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var llmService: LLMService
    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var downloadViewModel: ModelDownloadViewModel

    var body: some View {
        if settings.hasCompletedOnboarding && llmService.isLoaded {
            ContentView(
                chatViewModel: chatViewModel,
                settingsViewModel: settingsViewModel,
                downloadViewModel: downloadViewModel,
                llmService: llmService
            )
        } else {
            OnboardingView(
                downloadViewModel: downloadViewModel,
                settingsViewModel: settingsViewModel,
                llmService: llmService,
                hasCompletedOnboarding: Binding(
                    get: { settings.hasCompletedOnboarding },
                    set: { settings.hasCompletedOnboarding = $0 }
                )
            )
        }
    }
}
