import Combine
import CoreLocation
import Foundation
import OSLog

private let settingsLogger = Logger(subsystem: "app.lucidpal", category: "SettingsViewModel")

enum ConnectionTestResult {
    case idle
    case testing
    case success(Int)
    case failure(String)
}

@MainActor
final class SettingsViewModel: ObservableObject {

    // MARK: - Calendar (already mirrored)
    @Published var calendarAuthStatus: CalendarAuthorizationStatus = .notDetermined
    @Published var calendarAccessEnabled: Bool = false
    @Published var defaultCalendarIdentifier: String = ""

    // MARK: - Location
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isResolvingCity = false
    @Published var locationEnabled: Bool = false
    @Published var userCity: String = ""

    // MARK: - Voice / Inference
    @Published var voiceAutoStartEnabled: Bool = false
    @Published var airpodsAutoVoiceEnabled: Bool = false
    @Published var speechAutoSendEnabled: Bool = false
    @Published var contextSize: Int = ChatConstants.defaultContextSizeTokens

    // MARK: - Web Search
    @Published var webSearchEnabled: Bool = false
    @Published var webSearchProvider: WebSearchProvider = .searxng
    @Published var braveApiKey: String = ""
    @Published var webSearchEndpoint: String = ""

    // MARK: - Vision
    @Published var visionEnabled: Bool = true

    // MARK: - Model list
    @Published var availableTextModels: [ModelInfo] = []
    @Published var availableVisionModels: [ModelInfo] = []

    // MARK: - Model selection (published for SwiftUI reactivity)
    var maxContextSize: Int { settings.maxContextSize }
    var deviceRAMGB: Int { settings.deviceRAMGB }
    @Published private(set) var selectedTextModelID: String = ""
    @Published private(set) var selectedVisionModelID: String = ""
    var webSearchSummary: String {
        webSearchEnabled ? webSearchProvider.displayName : "Off"
    }

    // MARK: - Private
    private let settings: any AppSettingsProtocol
    let calendarService: any CalendarServiceProtocol
    let locationService: (any LocationServiceProtocol)?
    private let webSearchServiceFactory: (any AppSettingsProtocol) -> any WebSearchServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(
        settings: any AppSettingsProtocol,
        calendarService: any CalendarServiceProtocol,
        locationService: (any LocationServiceProtocol)? = nil,
        webSearchServiceFactory: @escaping (any AppSettingsProtocol) -> any WebSearchServiceProtocol = { WebSearchService(settings: $0) }
    ) {
        self.settings = settings
        self.calendarService = calendarService
        self.locationService = locationService
        self.webSearchServiceFactory = webSearchServiceFactory

        // Seed published state from settings
        self.calendarAuthStatus = calendarService.authorizationStatus
        self.locationStatus = locationService?.authorizationStatus ?? .notDetermined
        self.availableTextModels = ModelInfo.textModels(physicalRAMGB: settings.deviceRAMGB)
        self.availableVisionModels = ModelInfo.visionModels(physicalRAMGB: settings.deviceRAMGB)
        self.calendarAccessEnabled = settings.calendarAccessEnabled
        self.defaultCalendarIdentifier = settings.defaultCalendarIdentifier
        self.locationEnabled = settings.locationEnabled
        self.userCity = settings.userCity
        self.voiceAutoStartEnabled = settings.voiceAutoStartEnabled
        self.airpodsAutoVoiceEnabled = settings.airpodsAutoVoiceEnabled
        self.speechAutoSendEnabled = settings.speechAutoSendEnabled
        self.contextSize = settings.contextSize
        self.webSearchEnabled = settings.webSearchEnabled
        self.webSearchProvider = settings.webSearchProvider
        self.braveApiKey = settings.braveApiKey
        self.webSearchEndpoint = settings.webSearchEndpoint
        self.visionEnabled = settings.visionEnabled
        self.selectedTextModelID = settings.selectedTextModelID
        self.selectedVisionModelID = settings.selectedVisionModelID

        if availableTextModels.isEmpty { availableTextModels = [.qwen3_5_2B] }
        if availableVisionModels.isEmpty { availableVisionModels = [.qwen3_5_vision] }

        setupPublishers()
    }

    // MARK: - Private setup

    private func setupPublishers() {
        // Calendar mirrors → settings
        $calendarAccessEnabled.dropFirst()
            .sink { [weak self] in self?.settings.calendarAccessEnabled = $0 }
            .store(in: &cancellables)
        $defaultCalendarIdentifier.dropFirst()
            .sink { [weak self] in self?.settings.defaultCalendarIdentifier = $0 }
            .store(in: &cancellables)

        // Location mirror → settings
        $locationEnabled.dropFirst()
            .sink { [weak self] in self?.settings.locationEnabled = $0 }
            .store(in: &cancellables)

        // Web Search mirrors → settings
        $webSearchEnabled.dropFirst()
            .sink { [weak self] in self?.settings.webSearchEnabled = $0 }
            .store(in: &cancellables)
        $webSearchProvider.dropFirst()
            .sink { [weak self] in self?.settings.webSearchProvider = $0 }
            .store(in: &cancellables)
        $braveApiKey.dropFirst()
            .sink { [weak self] in self?.settings.braveApiKey = $0 }
            .store(in: &cancellables)
        $webSearchEndpoint.dropFirst()
            .sink { [weak self] in self?.settings.webSearchEndpoint = $0 }
            .store(in: &cancellables)

        // Voice mirrors → settings
        $airpodsAutoVoiceEnabled.dropFirst()
            .sink { [weak self] in self?.settings.airpodsAutoVoiceEnabled = $0 }
            .store(in: &cancellables)
        $speechAutoSendEnabled.dropFirst()
            .sink { [weak self] in self?.settings.speechAutoSendEnabled = $0 }
            .store(in: &cancellables)
        $contextSize.dropFirst()
            .sink { [weak self] in self?.settings.contextSize = $0 }
            .store(in: &cancellables)

        // Vision mirror → settings
        $visionEnabled.dropFirst()
            .sink { [weak self] in self?.settings.visionEnabled = $0 }
            .store(in: &cancellables)
    }

    // MARK: - Calendar

    var isCalendarAuthorized: Bool { calendarService.isAuthorized }

    var availableCalendars: [CalendarInfo] { calendarService.writableCalendars() }

    func setDefaultCalendar(id: String?) {
        defaultCalendarIdentifier = id ?? ""
    }

    func requestCalendarAccess() async {
        _ = await calendarService.requestAccess()
        calendarAuthStatus = calendarService.authorizationStatus
        calendarAccessEnabled = calendarService.isAuthorized
    }

    // MARK: - Model

    func selectTextModel(_ model: ModelInfo) {
        settings.selectedTextModelID = model.id
        selectedTextModelID = model.id
    }

    func selectVisionModel(_ model: ModelInfo) {
        settings.selectedVisionModelID = model.id
        selectedVisionModelID = model.id
    }

    /// Refreshes published model IDs from settings (e.g. after another VM updates them).
    func refreshModelSelection() {
        selectedTextModelID = settings.selectedTextModelID
        selectedVisionModelID = settings.selectedVisionModelID
    }

    // MARK: - Voice

    #if DEBUG
    func replayOnboarding() {
        settings.hasCompletedOnboarding = false
    }
    #endif

    func setVoiceAutoStart(_ enabled: Bool) {
        voiceAutoStartEnabled = enabled
        settings.voiceAutoStartEnabled = enabled
        if enabled {
            speechAutoSendEnabled = true
            settings.speechAutoSendEnabled = true
        }
    }

    // MARK: - Location

    func requestLocationAccess() async {
        guard let svc = locationService else { return }
        isResolvingCity = true
        defer { isResolvingCity = false }
        let city = await svc.requestCity()
        locationStatus = svc.authorizationStatus
        if let city {
            settings.userCity = city
            settings.locationEnabled = true
            userCity = city
            locationEnabled = true
        } else if svc.authorizationStatus == .denied || svc.authorizationStatus == .restricted {
            settings.locationEnabled = false
            locationEnabled = false
        }
    }

    // MARK: - Web Search Connection Test

    @Published private(set) var connectionTestResult: ConnectionTestResult = .idle

    func runConnectionTest() async {
        connectionTestResult = .testing
        let svc = makeWebSearchService()
        do {
            let results = try await svc.search(query: "test", maxResults: 3)
            connectionTestResult = .success(results.count)
        } catch {
            connectionTestResult = .failure(error.localizedDescription)
        }
    }

    var isLocationServiceUnavailable: Bool { locationService == nil }

    /// Creates a WebSearchService scoped to the current web search settings.
    private func makeWebSearchService() -> any WebSearchServiceProtocol {
        webSearchServiceFactory(settings)
    }

    // MARK: - Storage

    var availableStorageGB: Double? {
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            guard let free = attrs[.systemFreeSize] as? Int64 else { return nil }
            return Double(free) / Double(ChatConstants.bytesPerGB)
        } catch {
            settingsLogger.warning("Failed to read filesystem attributes: \(error)")
            return nil
        }
    }
}
