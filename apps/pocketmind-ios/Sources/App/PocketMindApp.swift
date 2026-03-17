import SwiftUI

@main
struct PocketMindApp: App {
    private let settings = AppSettings()
    private let llmService = LLMService()
    private let calendarService = CalendarService()

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
                chatViewModel: chatViewModel,
                settingsViewModel: settingsViewModel,
                downloadViewModel: downloadViewModel
            )
        }
    }
}

private struct RootView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var downloadViewModel: ModelDownloadViewModel

    var body: some View {
        // Gate on downloadViewModel.isModelLoaded — never observe LLMService directly from a View
        if settings.hasCompletedOnboarding && downloadViewModel.isModelLoaded {
            ContentView(
                chatViewModel: chatViewModel,
                settingsViewModel: settingsViewModel,
                downloadViewModel: downloadViewModel
            )
        } else {
            OnboardingView(
                downloadViewModel: downloadViewModel,
                settingsViewModel: settingsViewModel,
                hasCompletedOnboarding: Binding(
                    get: { settings.hasCompletedOnboarding },
                    set: { settings.hasCompletedOnboarding = $0 }
                )
            )
        }
    }
}
