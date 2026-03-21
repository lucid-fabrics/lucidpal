import Foundation

@MainActor
final class AppSettings: ObservableObject, AppSettingsProtocol {

    // MARK: - Stored Preferences

    @Published var calendarAccessEnabled: Bool {
        didSet { UserDefaults.standard.set(calendarAccessEnabled, forKey: UserDefaultsKeys.calendarAccessEnabled) }
    }

    @Published var selectedModelID: String {
        didSet { UserDefaults.standard.set(selectedModelID, forKey: UserDefaultsKeys.selectedModelID) }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: UserDefaultsKeys.hasCompletedOnboarding) }
    }

    @Published var thinkingEnabled: Bool {
        didSet { UserDefaults.standard.set(thinkingEnabled, forKey: UserDefaultsKeys.thinkingEnabled) }
    }

    @Published var defaultCalendarIdentifier: String {
        didSet { UserDefaults.standard.set(defaultCalendarIdentifier, forKey: UserDefaultsKeys.defaultCalendarIdentifier) }
    }

    @Published var speechAutoSendEnabled: Bool {
        didSet { UserDefaults.standard.set(speechAutoSendEnabled, forKey: UserDefaultsKeys.speechAutoSendEnabled) }
    }

    @Published var voiceAutoStartEnabled: Bool {
        didSet { UserDefaults.standard.set(voiceAutoStartEnabled, forKey: UserDefaultsKeys.voiceAutoStartEnabled) }
    }

    @Published var contextSize: Int {
        didSet { UserDefaults.standard.set(contextSize, forKey: UserDefaultsKeys.contextSize) }
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        calendarAccessEnabled = defaults.bool(forKey: UserDefaultsKeys.calendarAccessEnabled)
        selectedModelID = defaults.string(forKey: UserDefaultsKeys.selectedModelID) ?? ModelInfo.qwen3_5_2B.id
        hasCompletedOnboarding = defaults.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding)
        thinkingEnabled = defaults.object(forKey: UserDefaultsKeys.thinkingEnabled) as? Bool ?? true
        defaultCalendarIdentifier = defaults.string(forKey: UserDefaultsKeys.defaultCalendarIdentifier) ?? ""
        speechAutoSendEnabled = defaults.object(forKey: UserDefaultsKeys.speechAutoSendEnabled) as? Bool ?? true
        voiceAutoStartEnabled = defaults.object(forKey: UserDefaultsKeys.voiceAutoStartEnabled) as? Bool ?? false
        contextSize = defaults.object(forKey: UserDefaultsKeys.contextSize) as? Int ?? 4096
    }

    // MARK: - Computed Properties

    var selectedModel: ModelInfo {
        [ModelInfo.qwen3_5_0B8, ModelInfo.qwen3_5_2B, ModelInfo.qwen3_5_4B]
            .first { $0.id == selectedModelID } ?? .qwen3_5_2B
    }

    var deviceRAMGB: Int {
        Int(ProcessInfo.processInfo.physicalMemory / Self.bytesPerGB)
    }

    var maxContextSize: Int {
        deviceRAMGB >= 6 ? 8192 : 4096
    }

    // MARK: - Private Constants

    private static let bytesPerGB: UInt64 = 1_073_741_824
}
