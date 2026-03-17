import SwiftUI

@main
struct PocketMindApp: App {

    // MARK: - Services

    private let settings = AppSettings()
    private let llmService = LLMService()
    private let calendarService = CalendarService()
    private let calendarActionController: CalendarActionController

    // MARK: - ViewModels

    private let chatViewModel: ChatViewModel
    private let settingsViewModel: SettingsViewModel
    private let downloadViewModel: ModelDownloadViewModel

    // MARK: - Initialization

    init() {
        let actionController = CalendarActionController(calendarService: calendarService)
        calendarActionController = actionController
        chatViewModel = ChatViewModel(
            llmService: llmService,
            calendarService: calendarService,
            calendarActionController: actionController,
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
        // Gate only on hasCompletedOnboarding — not isModelLoaded.
        // If the model unloads post-onboarding (memory pressure, delete), the user
        // stays in ContentView where ChatView shows the "no model" banner + Settings
        // link. Kicking back to Onboarding would orphan chat history.
        if settings.hasCompletedOnboarding {
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
