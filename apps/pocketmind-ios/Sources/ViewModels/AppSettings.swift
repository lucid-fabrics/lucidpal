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

    @Published var airpodsAutoVoiceEnabled: Bool {
        didSet { UserDefaults.standard.set(airpodsAutoVoiceEnabled, forKey: UserDefaultsKeys.airpodsAutoVoiceEnabled) }
    }

    @Published var contextSize: Int {
        didSet { UserDefaults.standard.set(contextSize, forKey: UserDefaultsKeys.contextSize) }
    }

    @Published var notesAccessEnabled: Bool {
        didSet { UserDefaults.standard.set(notesAccessEnabled, forKey: UserDefaultsKeys.notesAccessEnabled) }
    }

    @Published var remindersAccessEnabled: Bool {
        didSet { UserDefaults.standard.set(remindersAccessEnabled, forKey: UserDefaultsKeys.remindersAccessEnabled) }
    }

    @Published var mailAccessEnabled: Bool {
        didSet { UserDefaults.standard.set(mailAccessEnabled, forKey: UserDefaultsKeys.mailAccessEnabled) }
    }

    @Published var webSearchEnabled: Bool {
        didSet { UserDefaults.standard.set(webSearchEnabled, forKey: UserDefaultsKeys.webSearchEnabled) }
    }

    @Published var webSearchProvider: WebSearchProvider {
        didSet { UserDefaults.standard.set(webSearchProvider.rawValue, forKey: UserDefaultsKeys.webSearchProvider) }
    }

    @Published var webSearchEndpoint: String {
        didSet { UserDefaults.standard.set(webSearchEndpoint, forKey: UserDefaultsKeys.webSearchEndpoint) }
    }

    @Published var braveApiKey: String {
        didSet { UserDefaults.standard.set(braveApiKey, forKey: UserDefaultsKeys.braveApiKey) }
    }

    @Published var locationEnabled: Bool {
        didSet { UserDefaults.standard.set(locationEnabled, forKey: UserDefaultsKeys.locationEnabled) }
    }

    @Published var userCity: String {
        didSet { UserDefaults.standard.set(userCity, forKey: UserDefaultsKeys.userCity) }
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
        airpodsAutoVoiceEnabled = defaults.object(forKey: UserDefaultsKeys.airpodsAutoVoiceEnabled) as? Bool ?? false
        contextSize = defaults.object(forKey: UserDefaultsKeys.contextSize) as? Int ?? ChatConstants.defaultContextSizeTokens
        notesAccessEnabled = defaults.bool(forKey: UserDefaultsKeys.notesAccessEnabled)
        remindersAccessEnabled = defaults.bool(forKey: UserDefaultsKeys.remindersAccessEnabled)
        mailAccessEnabled = defaults.bool(forKey: UserDefaultsKeys.mailAccessEnabled)
        webSearchEnabled = defaults.bool(forKey: UserDefaultsKeys.webSearchEnabled)
        webSearchProvider = WebSearchProvider(rawValue: defaults.string(forKey: UserDefaultsKeys.webSearchProvider) ?? "") ?? .brave
        webSearchEndpoint = defaults.string(forKey: UserDefaultsKeys.webSearchEndpoint) ?? ""
        braveApiKey = defaults.string(forKey: UserDefaultsKeys.braveApiKey) ?? ""
        locationEnabled = defaults.bool(forKey: UserDefaultsKeys.locationEnabled)
        userCity = defaults.string(forKey: UserDefaultsKeys.userCity) ?? ""
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
        deviceRAMGB >= ChatConstants.largeContextRAMThresholdGB ? ChatConstants.largeContextSizeTokens : ChatConstants.defaultContextSizeTokens
    }

    // MARK: - Private Constants

    private static let bytesPerGB: UInt64 = 1_073_741_824
}
