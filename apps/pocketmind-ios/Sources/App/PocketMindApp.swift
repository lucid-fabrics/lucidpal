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

    // MARK: - Environment

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Initialization

    init() {
        let actionController = CalendarActionController(calendarService: calendarService, settings: settings)
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

        // Cancel LLM generation on memory pressure to avoid Jetsam crash
        let service = llmService
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in service.cancelGeneration() }
        }
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            RootView(
                settings: settings,
                chatViewModel: chatViewModel,
                settingsViewModel: settingsViewModel,
                downloadViewModel: downloadViewModel
            )
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            consumePendingSiriQuery()
        }
    }

    // MARK: - Siri Integration

    private func consumePendingSiriQuery() {
        guard let query = UserDefaults.standard.string(forKey: "pm_siri_pending_query"),
              !query.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: "pm_siri_pending_query")
        guard chatViewModel.isModelLoaded else {
            chatViewModel.errorMessage = "Model not ready — please wait for it to load, then ask again."
            return
        }
        chatViewModel.handleSiriQuery(query)
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
