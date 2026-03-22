import OSLog
import SwiftUI

private let appLogger = Logger(subsystem: "app.pocketmind", category: "PocketMindApp")

// Wrapper so the NotificationCenter token is removed in deinit.
// PocketMindApp is a struct and cannot have deinit directly.
private final class MemoryPressureObserver {
    private let token: any NSObjectProtocol

    init(onWarning: @escaping () -> Void) {
        token = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { _ in onWarning() }
    }

    deinit {
        NotificationCenter.default.removeObserver(token)
    }
}

@main
struct PocketMindApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate


    // MARK: - Services

    private let settings = AppSettings()
    private let llmService = LLMService()
    private let calendarService = CalendarService()
    private let speechService = WhisperSpeechService()
    private let hapticService = HapticService()
    private let modelDownloader = ModelDownloader()
    private let calendarActionController: any CalendarActionControllerProtocol
    private let audioRouteMonitor = AudioRouteMonitor()
    private let airPodsCoordinator: AirPodsVoiceCoordinator

    // MARK: - ViewModels

    private let sessionListViewModel: SessionListViewModel
    private let settingsViewModel: SettingsViewModel
    private let downloadViewModel: ModelDownloadViewModel

    private let memoryWarningObserver: MemoryPressureObserver

    // MARK: - Environment

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Initialization

    init() {
        let actionController = CalendarActionController(calendarService: calendarService, settings: settings)
        calendarActionController = actionController
        airPodsCoordinator = AirPodsVoiceCoordinator(
            audioRouteMonitor: audioRouteMonitor,
            speechService: speechService,
            settings: settings
        )
        let sessionManager = SessionManager()
        sessionListViewModel = SessionListViewModel(
            sessionManager: sessionManager,
            llmService: llmService,
            calendarService: calendarService,
            calendarActionController: actionController,
            settings: settings,
            speechService: speechService,
            hapticService: hapticService,
            airPodsCoordinator: airPodsCoordinator
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
        let service = llmService
        memoryWarningObserver = MemoryPressureObserver {
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
        guard let query = UserDefaults.standard.string(forKey: UserDefaultsKeys.siriPendingQuery),
              !query.isEmpty else { return }
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.siriPendingQuery)
        sessionListViewModel.scheduleSiriQuery(query)
    }

    private func consumePendingSiriEvent() {
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.siriPendingEvent) else { return }
        let event: SiriPendingEvent
        do {
            event = try JSONDecoder().decode(SiriPendingEvent.self, from: data)
        } catch {
            appLogger.error("Failed to decode pending Siri event: \(error)")
            UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.siriPendingEvent)
            return
        }
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.siriPendingEvent)
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
