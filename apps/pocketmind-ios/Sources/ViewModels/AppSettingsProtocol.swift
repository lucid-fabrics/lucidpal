import Foundation

// MARK: - Focused sub-protocols (ISP)

/// Calendar permission and default calendar identity settings.
@MainActor
protocol CalendarSettingsProtocol: AnyObject {
    var calendarAccessEnabled: Bool { get set }
    var defaultCalendarIdentifier: String { get set }
}

/// LLM inference and model-selection settings.
@MainActor
protocol InferenceSettingsProtocol: AnyObject {
    var selectedModelID: String { get set }
    var contextSize: Int { get set }
    var thinkingEnabled: Bool { get set }
    var selectedModel: ModelInfo { get }
    var maxContextSize: Int { get }
    var deviceRAMGB: Int { get }
}

/// Voice and speech input settings.
@MainActor
protocol VoiceSettingsProtocol: AnyObject {
    var speechAutoSendEnabled: Bool { get set }
    var voiceAutoStartEnabled: Bool { get set }
    var airpodsAutoVoiceEnabled: Bool { get set }
}

/// Web search provider and credential settings.
@MainActor
protocol WebSearchSettingsProtocol: AnyObject {
    var webSearchEnabled: Bool { get set }
    var webSearchProvider: WebSearchProvider { get set }
    var webSearchEndpoint: String { get set }
    var braveApiKey: String { get set }
}

/// Location and city settings.
@MainActor
protocol LocationSettingsProtocol: AnyObject {
    var locationEnabled: Bool { get set }
    var userCity: String { get set }
}

// MARK: - Composite protocol

/// Full settings contract used at the composition root and by components that
/// need access across multiple concern domains. Prefer a narrower sub-protocol
/// when a consumer only touches one domain (e.g. WebSearchService → WebSearchSettingsProtocol).
@MainActor
protocol AppSettingsProtocol: CalendarSettingsProtocol,
                               InferenceSettingsProtocol,
                               VoiceSettingsProtocol,
                               WebSearchSettingsProtocol,
                               LocationSettingsProtocol {
    var hasCompletedOnboarding: Bool { get set }
    var notesAccessEnabled: Bool { get set }
    var remindersAccessEnabled: Bool { get set }
    var mailAccessEnabled: Bool { get set }
}
