import SwiftUI

@main
struct PocketMindApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate


    // MARK: - Services

    private let settings = AppSettings()
    private let llmService = LLMService()
    private let calendarService = CalendarService()
    private let speechService = SpeechService()
    private let hapticService = HapticService()
    private let modelDownloader = ModelDownloader()
    private let calendarActionController: any CalendarActionControllerProtocol

    // MARK: - ViewModels

    private let sessionListViewModel: SessionListViewModel
    private let settingsViewModel: SettingsViewModel
    private let downloadViewModel: ModelDownloadViewModel

    // Stored so the system doesn't immediately deallocate the observer.
    private var memoryWarningObserver: (any NSObjectProtocol)?

    // MARK: - Environment

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Initialization

    init() {
        let actionController = CalendarActionController(calendarService: calendarService, settings: settings)
        calendarActionController = actionController
        let sessionManager = SessionManager()
        sessionListViewModel = SessionListViewModel(
            sessionManager: sessionManager,
            llmService: llmService,
            calendarService: calendarService,
            calendarActionController: actionController,
            settings: settings,
            speechService: speechService,
            hapticService: hapticService
        )
        settingsViewModel = SettingsViewModel(
            settings: settings,
            calendarService: calendarService
        )
        downloadViewModel = ModelDownloadViewModel(
            llmService: llmService,
            settings: settings,
            downloader: modelDownloader
        )

        // Cancel LLM generation on memory pressure to avoid Jetsam crash.
        // Token is stored in memoryWarningObserver to prevent premature deallocation.
        let service = llmService
        memoryWarningObserver = NotificationCenter.default.addObserver(
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
                sessionListViewModel: sessionListViewModel,
                settingsViewModel: settingsViewModel,
                downloadViewModel: downloadViewModel
            )
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                consumePendingSiriQuery()
                consumePendingSiriEvent()
            }
            // Background persistence is handled per-session by ChatSessionContainer.
        }
    }

    // MARK: - Siri Integration

    private func consumePendingSiriQuery() {
        guard let query = UserDefaults.standard.string(forKey: "pm_siri_pending_query"),
              !query.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: "pm_siri_pending_query")
        sessionListViewModel.scheduleSiriQuery(query)
    }

    private func consumePendingSiriEvent() {
        guard let data = UserDefaults.standard.data(forKey: "pm_siri_pending_event"),
              let event = try? JSONDecoder().decode(SiriPendingEvent.self, from: data) else { return }
        UserDefaults.standard.removeObject(forKey: "pm_siri_pending_event")
        sessionListViewModel.scheduleCreateEvent(event)
    }
}

private struct RootView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var sessionListViewModel: SessionListViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var downloadViewModel: ModelDownloadViewModel

    var body: some View {
        // Gate only on hasCompletedOnboarding — not isModelLoaded.
        // If the model unloads post-onboarding (memory pressure, delete), the user
        // stays in ContentView where ChatView shows the "no model" banner + Settings
        // link. Kicking back to Onboarding would orphan chat history.
        if settings.hasCompletedOnboarding {
            ContentView(
                sessionListViewModel: sessionListViewModel,
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
