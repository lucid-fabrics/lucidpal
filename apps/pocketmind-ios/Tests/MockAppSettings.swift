import Foundation
@testable import PocketMind

@MainActor
final class MockAppSettings: AppSettingsProtocol {
    var calendarAccessEnabled: Bool = false
    var selectedModelID: String = ModelInfo.qwen3_1B7.id
    var hasCompletedOnboarding: Bool = false
    var thinkingEnabled: Bool = true
    var defaultCalendarIdentifier: String = ""
    var speechAutoSendEnabled: Bool = true

    var selectedModel: ModelInfo {
        [ModelInfo.qwen3_1B7, ModelInfo.qwen3_4B]
            .first { $0.id == selectedModelID } ?? .qwen3_1B7
    }

    var deviceRAMGB: Int = 4
}
