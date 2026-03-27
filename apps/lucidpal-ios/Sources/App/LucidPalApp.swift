import Metal
import OSLog
import SwiftUI

private let appLogger = Logger(subsystem: "app.lucidpal", category: "LucidPalApp")

// Wrapper so the NotificationCenter token is removed in deinit.
// LucidPalApp is a struct and cannot have deinit directly.
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
struct LucidPalApp: App {
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
    private let airPodsCoordinator: any AirPodsVoiceCoordinatorProtocol
    private let webSearchService: any WebSearchServiceProtocol
    private let contextService: any ContextServiceProtocol
    private let locationService: any LocationServiceProtocol = LocationService()

    // MARK: - ViewModels

    private let sessionListViewModel: SessionListViewModel
    private let settingsViewModel: SettingsViewModel
    private let downloadViewModel: ModelDownloadViewModel

    private let memoryWarningObserver: MemoryPressureObserver

    // MARK: - Environment

    @Environment(\.scenePhase) private var scenePhase

    // MARK: - Initialization

    init() {
        // Force Metal driver initialization before model loading begins.
        // Eliminates 1–3 s of shader compilation from the first model load.
        _ = MTLCreateSystemDefaultDevice()

        let actionController = CalendarActionController(calendarService: calendarService, settings: settings)
        calendarActionController = actionController
        airPodsCoordinator = AirPodsVoiceCoordinator(
            audioRouteMonitor: audioRouteMonitor,
            speechService: speechService,
            settings: settings
        )
        webSearchService = WebSearchService(settings: settings)
        contextService = ContextService(settings: settings)
        let sessionManager = SessionManager()
        sessionListViewModel = SessionListViewModel(
            sessionManager: sessionManager,
            dependencies: SessionListViewModelDependencies(
                llmService: llmService,
                calendarService: calendarService,
                calendarActionController: actionController,
                settings: settings,
                speechService: speechService,
                hapticService: hapticService,
                contextService: contextService,
                airPodsCoordinator: airPodsCoordinator,
                webSearchService: webSearchService
            )
        )
        settingsViewModel = SettingsViewModel(
            settings: settings,
            calendarService: calendarService,
            locationService: locationService
        )
        downloadViewModel = ModelDownloadViewModel(
            llmService: llmService,
            settings: settings,
            downloader: modelDownloader
        )

        // On memory pressure: cancel generation AND unload the model to free KV-cache
        // and model weights. Without unloading, Jetsam can still kill the app because
        // the model remains resident even after generation stops.
        let service = llmService
        memoryWarningObserver = MemoryPressureObserver {
            Task { @MainActor in
                service.cancelGeneration()
                service.unload()
            }
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
                hintModelPageCache()
            }
            if phase == .background {
                AppDelegate.scheduleCalendarRefresh()
            }
            // Background persistence is handled per-session by ChatSessionContainer.
        }
    }

    // MARK: - Page Cache Warming

    /// Tracks an in-flight page cache hint task to avoid redundant concurrent hints.
    /// All reads and writes are on the MainActor (hintModelPageCache is @MainActor,
    /// the Task callback uses MainActor.run). @MainActor annotation enforces this.
    @MainActor private static var activeHintTask: Task<Void, Never>?

    /// Hints the kernel to prefetch the selected model file's first 64 MB into the
    /// page cache via F_RDADVISE before llama.cpp mmap-loads it. Reduces demand-paging
    /// stalls on initial inference. No-op if the model is already loaded or not downloaded.
    /// At most one hint runs at a time — rapid scene-phase transitions are collapsed.
    @MainActor private func hintModelPageCache() {
        guard !downloadViewModel.isModelLoaded, !downloadViewModel.isModelLoading else { return }
        guard Self.activeHintTask == nil else { return } // hint already in flight
        let id = settings.selectedTextModelID
        guard !id.isEmpty else { return }
        let models = ModelInfo.available(physicalRAMGB: settings.deviceRAMGB)
        guard let model = models.first(where: { $0.id == id }), model.isDownloaded else { return }
        Self.activeHintTask = Task.detached(priority: .utility) {
            ModelPageCacheWarmer.hint(fileURL: model.localURL)
            // Clear on all exit paths (completion and cancellation) so hintModelPageCache
            // can start a fresh hint the next time the app becomes active.
            await MainActor.run { Self.activeHintTask = nil }
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

    /// True when the device has ≥ 6 GB physical RAM (iPhone 12 Pro minimum).
    /// Always true in the simulator so developers can work normally.
    /// Computed once as a `let` — physicalMemory is constant for the device lifetime.
    static let isDeviceSupported: Bool = {
        #if targetEnvironment(simulator)
        return true
        #else
        // 3 GB threshold blocks devices with less than 3 GB RAM (too small even for the
        // 0.8 B model). 4 GB devices (iPhone 12/13/SE3) are supported with a reduced
        // 2048-token context window. physicalMemory on 4 GB devices ≈ 4_294_967_296.
        let minRAMThreshold: UInt64 = 3_221_225_472
        return ProcessInfo.processInfo.physicalMemory >= minRAMThreshold
        #endif
    }()

    /// Auto-loads the last used text model on app launch if one was previously selected and downloaded.
    private func autoLoadLastModel() async {
        guard !downloadViewModel.isModelLoaded,
              !downloadViewModel.isModelLoading else { return }
        let savedID = settings.selectedTextModelID
        guard !savedID.isEmpty else { return }
        let allModels = ModelInfo.available(physicalRAMGB: settings.deviceRAMGB)
        guard let model = allModels.first(where: { $0.id == savedID }),
              model.isDownloaded else { return }
        downloadViewModel.selectModel(model)
        await downloadViewModel.loadModel()
        settingsViewModel.refreshModelSelection()
    }

    var body: some View {
        if !Self.isDeviceSupported {
            UnsupportedDeviceView()
        } else if settings.hasCompletedOnboarding {
            ContentView(
                sessionListViewModel: sessionListViewModel,
                settingsViewModel: settingsViewModel,
                downloadViewModel: downloadViewModel
            )
            .task { await autoLoadLastModel() }
        } else {
            OnboardingCarouselView(
                downloadViewModel: downloadViewModel,
                hasCompletedOnboarding: Binding(
                    get: { settings.hasCompletedOnboarding },
                    set: { settings.hasCompletedOnboarding = $0 }
                )
            )
        }
    }
}
