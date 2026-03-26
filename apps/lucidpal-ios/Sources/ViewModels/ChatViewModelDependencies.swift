import Foundation

/// Groups all service dependencies for ChatViewModel.
/// Pass this struct to the init instead of individual service parameters —
/// reduces the injection site from 10+ parameters to 5.
struct ChatViewModelDependencies {
    let llmService: any LLMServiceProtocol
    let calendarService: any CalendarServiceProtocol
    let settings: any AppSettingsProtocol
    let systemPromptBuilder: any SystemPromptBuilderProtocol
    let suggestedPromptsProvider: any SuggestedPromptsProviderProtocol
    let speechService: any SpeechServiceProtocol
    let hapticService: any HapticServiceProtocol
    let historyManager: any ChatHistoryManagerProtocol
    let airPodsCoordinator: (any AirPodsVoiceCoordinatorProtocol)?
    let webSearchService: (any WebSearchServiceProtocol)?
}
