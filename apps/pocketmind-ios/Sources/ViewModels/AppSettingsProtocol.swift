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
    var selectedModel: ModelInfo { get }
    var deviceRAMGB: Int { get }
}
