import Foundation
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {

    // MARK: - Stored Preferences

    @AppStorage("calendarAccessEnabled") var calendarAccessEnabled: Bool = false
    @AppStorage("selectedModelID") var selectedModelID: String = ModelInfo.qwen3_1B7.id
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("thinkingEnabled") var thinkingEnabled: Bool = true

    // MARK: - Computed Properties

    var selectedModel: ModelInfo {
        // Array lookup — adding new models requires no changes here
        [ModelInfo.qwen3_1B7, ModelInfo.qwen3_4B]
            .first { $0.id == selectedModelID } ?? .qwen3_1B7
    }

    var deviceRAMGB: Int {
        Int(ProcessInfo.processInfo.physicalMemory / Self.bytesPerGB)
    }

    // MARK: - Private Constants

    private static let bytesPerGB: UInt64 = 1_073_741_824
}
