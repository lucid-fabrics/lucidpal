import Foundation

/// Groups all service dependencies for `SessionListViewModel` — mirrors the pattern
/// used by `ChatViewModelDependencies` to keep the view-model init under six parameters.
struct SessionListViewModelDependencies {
    let llmService: any LLMServiceProtocol
    let calendarService: any CalendarServiceProtocol
    let calendarActionController: any CalendarActionControllerProtocol
    let settings: any AppSettingsProtocol
    let speechService: any SpeechServiceProtocol
    let hapticService: any HapticServiceProtocol
    let contextService: any ContextServiceProtocol
    let airPodsCoordinator: (any AirPodsVoiceCoordinatorProtocol)?
    let webSearchService: (any WebSearchServiceProtocol)?
    /// Override for testing — nil uses `SystemPromptBuilder` with the injected services.
    let makeSystemPromptBuilder: (() -> any SystemPromptBuilderProtocol)?
    /// Override for testing — nil uses `SuggestedPromptsProvider` with the injected calendar service.
    let makeSuggestedPromptsProvider: (() -> any SuggestedPromptsProviderProtocol)?

    init(
        llmService: any LLMServiceProtocol,
        calendarService: any CalendarServiceProtocol,
        calendarActionController: any CalendarActionControllerProtocol,
        settings: any AppSettingsProtocol,
        speechService: any SpeechServiceProtocol,
        hapticService: any HapticServiceProtocol,
        contextService: any ContextServiceProtocol,
        airPodsCoordinator: (any AirPodsVoiceCoordinatorProtocol)? = nil,
        webSearchService: (any WebSearchServiceProtocol)? = nil,
        makeSystemPromptBuilder: ((() -> any SystemPromptBuilderProtocol))? = nil,
        makeSuggestedPromptsProvider: ((() -> any SuggestedPromptsProviderProtocol))? = nil
    ) {
        self.llmService = llmService
        self.calendarService = calendarService
        self.calendarActionController = calendarActionController
        self.settings = settings
        self.speechService = speechService
        self.hapticService = hapticService
        self.contextService = contextService
        self.airPodsCoordinator = airPodsCoordinator
        self.webSearchService = webSearchService
        self.makeSystemPromptBuilder = makeSystemPromptBuilder
        self.makeSuggestedPromptsProvider = makeSuggestedPromptsProvider
    }
}
