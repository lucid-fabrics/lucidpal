import Foundation

@MainActor
final class AppSettings: ObservableObject, AppSettingsProtocol {

    // MARK: - Stored Preferences

    @Published var calendarAccessEnabled: Bool {
        didSet { UserDefaults.standard.set(calendarAccessEnabled, forKey: "calendarAccessEnabled") }
    }

    @Published var selectedModelID: String {
        didSet { UserDefaults.standard.set(selectedModelID, forKey: "selectedModelID") }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    @Published var thinkingEnabled: Bool {
        didSet { UserDefaults.standard.set(thinkingEnabled, forKey: "thinkingEnabled") }
    }

    @Published var defaultCalendarIdentifier: String {
        didSet { UserDefaults.standard.set(defaultCalendarIdentifier, forKey: "defaultCalendarIdentifier") }
    }

    @Published var speechAutoSendEnabled: Bool {
        didSet { UserDefaults.standard.set(speechAutoSendEnabled, forKey: "speechAutoSendEnabled") }
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        calendarAccessEnabled = defaults.bool(forKey: "calendarAccessEnabled")
        selectedModelID = defaults.string(forKey: "selectedModelID") ?? ModelInfo.qwen3_5_2B.id
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        thinkingEnabled = defaults.object(forKey: "thinkingEnabled") as? Bool ?? true
        defaultCalendarIdentifier = defaults.string(forKey: "defaultCalendarIdentifier") ?? ""
        speechAutoSendEnabled = defaults.object(forKey: "speechAutoSendEnabled") as? Bool ?? true
    }

    // MARK: - Computed Properties

    var selectedModel: ModelInfo {
        [ModelInfo.qwen3_5_0B8, ModelInfo.qwen3_5_2B, ModelInfo.qwen3_5_4B]
            .first { $0.id == selectedModelID } ?? .qwen3_5_2B
    }

    var deviceRAMGB: Int {
        Int(ProcessInfo.processInfo.physicalMemory / Self.bytesPerGB)
    }

    // MARK: - Private Constants

    private static let bytesPerGB: UInt64 = 1_073_741_824
}
