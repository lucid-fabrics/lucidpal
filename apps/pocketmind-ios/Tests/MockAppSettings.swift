import Foundation
@testable import PocketMind

@MainActor
final class MockAppSettings: AppSettingsProtocol {
    var calendarAccessEnabled: Bool = false
    var selectedTextModelID: String = ModelInfo.qwen3_5_2B.id
    var hasCompletedOnboarding: Bool = false
    var thinkingEnabled: Bool = true
    var defaultCalendarIdentifier: String = ""
    var speechAutoSendEnabled: Bool = true
    var voiceAutoStartEnabled: Bool = false
    var airpodsAutoVoiceEnabled: Bool = false
    var contextSize: Int = ChatConstants.defaultContextSizeTokens
    var notesAccessEnabled: Bool = false
    var remindersAccessEnabled: Bool = false
    var mailAccessEnabled: Bool = false
    var webSearchEnabled: Bool = false
    var webSearchProvider: WebSearchProvider = .brave
    var webSearchEndpoint: String = ""
    var braveApiKey: String = ""
    var locationEnabled: Bool = false
    var userCity: String = ""
    var visionEnabled: Bool = true
    var selectedVisionModelID: String = ModelInfo.qwen3_5_vision.id

    var selectedTextModel: ModelInfo {
        [.qwen3_5_0B8, .qwen3_5_2B, .qwen3_5_4B, .qwen3_5_vision]
            .first { $0.id == selectedTextModelID } ?? .qwen3_5_2B
    }

    var selectedVisionModel: ModelInfo {
        [.qwen3_5_vision]
            .first { $0.id == selectedVisionModelID } ?? .qwen3_5_vision
    }

    var deviceRAMGB: Int = 4
    var maxContextSize: Int {
        deviceRAMGB >= ChatConstants.largeContextRAMThresholdGB ? ChatConstants.largeContextSizeTokens : ChatConstants.defaultContextSizeTokens
    }

    // Backwards-compat
    var selectedModelID: String {
        get { selectedTextModelID }
        set { selectedTextModelID = newValue }
    }

    var selectedModel: ModelInfo { selectedTextModel }
}
