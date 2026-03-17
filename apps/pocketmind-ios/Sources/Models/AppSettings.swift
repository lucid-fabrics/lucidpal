import Foundation
import SwiftUI

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("calendarAccessEnabled") var calendarAccessEnabled: Bool = false
    @AppStorage("selectedModelID") var selectedModelID: String = ModelInfo.qwen3_1B7.id
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("thinkingEnabled") var thinkingEnabled: Bool = true

    var selectedModel: ModelInfo {
        switch selectedModelID {
        case ModelInfo.qwen3_4B.id: return .qwen3_4B
        default: return .qwen3_1B7
        }
    }

    var deviceRAMGB: Int {
        let bytes = ProcessInfo.processInfo.physicalMemory
        return Int(bytes / 1_073_741_824) // bytes → GB
    }
}
