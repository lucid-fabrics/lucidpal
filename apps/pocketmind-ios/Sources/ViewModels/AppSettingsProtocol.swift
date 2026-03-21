import Foundation

// MARK: - AppSettings protocol

/// Protocol for all ViewModel dependencies on app-level settings.
/// Allows ViewModels to be tested without @AppStorage or UserDefaults.
@MainActor
protocol AppSettingsProtocol: AnyObject {
    var calendarAccessEnabled: Bool { get set }
    var selectedModelID: String { get set }
    var hasCompletedOnboarding: Bool { get set }
    var thinkingEnabled: Bool { get set }
    var defaultCalendarIdentifier: String { get set }
    var speechAutoSendEnabled: Bool { get set }
    var voiceAutoStartEnabled: Bool { get set }
    /// User-selected KV cache context window in tokens. Affects memory use and max conversation length.
    var contextSize: Int { get set }
    var selectedModel: ModelInfo { get }
    var deviceRAMGB: Int { get }
    /// Maximum context size this device can safely support.
    var maxContextSize: Int { get }
}
