import Foundation
import SwiftUI

@MainActor
final class AppSettings: ObservableObject, AppSettingsProtocol {

    // MARK: - Stored Preferences

    @AppStorage("calendarAccessEnabled") var calendarAccessEnabled: Bool = false
    @AppStorage("selectedModelID") var selectedModelID: String = ModelInfo.qwen3_5_2B.id
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("thinkingEnabled") var thinkingEnabled: Bool = true
    @AppStorage("defaultCalendarIdentifier") var defaultCalendarIdentifier: String = ""
    @AppStorage("speechAutoSendEnabled") var speechAutoSendEnabled: Bool = true

    // MARK: - Computed Properties

    var selectedModel: ModelInfo {
        // Array lookup — adding new models requires no changes here
        [ModelInfo.qwen3_5_0B8, ModelInfo.qwen3_5_2B, ModelInfo.qwen3_5_4B]
            .first { $0.id == selectedModelID } ?? .qwen3_5_2B
    }

    var deviceRAMGB: Int {
        Int(ProcessInfo.processInfo.physicalMemory / Self.bytesPerGB)
    }

    // MARK: - Private Constants

    private static let bytesPerGB: UInt64 = 1_073_741_824
}
