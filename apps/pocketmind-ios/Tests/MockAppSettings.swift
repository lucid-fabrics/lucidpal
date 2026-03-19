import Foundation
@testable import PocketMind

@MainActor
final class MockAppSettings: AppSettingsProtocol {
    var calendarAccessEnabled: Bool = false
    var selectedModelID: String = ModelInfo.qwen3_5_2B.id
    var hasCompletedOnboarding: Bool = false
    var thinkingEnabled: Bool = true
    var defaultCalendarIdentifier: String = ""
    var speechAutoSendEnabled: Bool = true

    var selectedModel: ModelInfo {
        [ModelInfo.qwen3_5_0B8, ModelInfo.qwen3_5_2B, ModelInfo.qwen3_5_4B]
            .first { $0.id == selectedModelID } ?? .qwen3_5_2B
    }

    var deviceRAMGB: Int = 4
}
