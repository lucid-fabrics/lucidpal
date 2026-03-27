import Foundation
import Security

@MainActor
final class AppSettings: ObservableObject, AppSettingsProtocol {

    // MARK: - Stored Preferences

    @Published var calendarAccessEnabled: Bool {
        didSet { UserDefaults.standard.set(calendarAccessEnabled, forKey: UserDefaultsKeys.calendarAccessEnabled) }
    }

    /// ID of the selected text inference model.
    @Published var selectedTextModelID: String {
        didSet { UserDefaults.standard.set(selectedTextModelID, forKey: UserDefaultsKeys.selectedTextModelID) }
    }

    /// ID of the selected vision model (may be the same as text model if integrated).
    @Published var selectedVisionModelID: String {
        didSet { UserDefaults.standard.set(selectedVisionModelID, forKey: UserDefaultsKeys.selectedVisionModelID) }
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

    @Published var temperature: Double {
        didSet { UserDefaults.standard.set(temperature, forKey: UserDefaultsKeys.temperature) }
    }

    @Published var maxResponseTokens: Int {
        didSet { UserDefaults.standard.set(maxResponseTokens, forKey: UserDefaultsKeys.maxResponseTokens) }
    }

    @Published var generationTimeout: Double {
        didSet { UserDefaults.standard.set(generationTimeout, forKey: UserDefaultsKeys.generationTimeout) }
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

    // Brave API key is stored in the Keychain (never in UserDefaults) to prevent
    // exposure in backups and system log access.
    @Published var braveApiKey: String {
        didSet { Self.keychainSet(braveApiKey, forKey: UserDefaultsKeys.braveApiKey) }
    }

    @Published var locationEnabled: Bool {
        didSet { UserDefaults.standard.set(locationEnabled, forKey: UserDefaultsKeys.locationEnabled) }
    }

    @Published var userCity: String {
        didSet { UserDefaults.standard.set(userCity, forKey: UserDefaultsKeys.userCity) }
    }

    @Published var visionEnabled: Bool {
        didSet { UserDefaults.standard.set(visionEnabled, forKey: UserDefaultsKeys.visionEnabled) }
    }

    // MARK: - Init (with migration from legacy selectedModelID)

    init() {
        let defaults = UserDefaults.standard
        let legacyModelID = defaults.string(forKey: UserDefaultsKeys.selectedModelID)

        // Migrate: prefer new keys, fall back to legacy for first launch
        selectedTextModelID = defaults.string(forKey: UserDefaultsKeys.selectedTextModelID)
            ?? legacyModelID
            ?? ModelInfo.qwen3_5_2B.id

        selectedVisionModelID = defaults.string(forKey: UserDefaultsKeys.selectedVisionModelID)
            ?? ModelInfo.qwen3_5_vision.id

        calendarAccessEnabled = defaults.bool(forKey: UserDefaultsKeys.calendarAccessEnabled)
        hasCompletedOnboarding = defaults.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding)
        thinkingEnabled = defaults.object(forKey: UserDefaultsKeys.thinkingEnabled) as? Bool ?? true
        defaultCalendarIdentifier = defaults.string(forKey: UserDefaultsKeys.defaultCalendarIdentifier) ?? ""
        speechAutoSendEnabled = defaults.object(forKey: UserDefaultsKeys.speechAutoSendEnabled) as? Bool ?? true
        voiceAutoStartEnabled = defaults.object(forKey: UserDefaultsKeys.voiceAutoStartEnabled) as? Bool ?? false
        airpodsAutoVoiceEnabled = defaults.object(forKey: UserDefaultsKeys.airpodsAutoVoiceEnabled) as? Bool ?? false
        // Clamp the saved context size to the device's RAM-safe maximum.
        // Prevents OOM on 4 GB devices that had a larger value stored from a previous device.
        let ramGB = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
        let contextSizeCap = ramGB >= ChatConstants.largeContextRAMThresholdGB
            ? ChatConstants.largeContextSizeTokens
            : ChatConstants.tinyContextSizeTokens
        let savedContextSize = defaults.object(forKey: UserDefaultsKeys.contextSize) as? Int ?? ChatConstants.defaultContextSizeTokens
        contextSize = min(savedContextSize, contextSizeCap)
        temperature = defaults.object(forKey: UserDefaultsKeys.temperature) as? Double ?? Double(LLMConstants.samplerTemperature)
        maxResponseTokens = defaults.object(forKey: UserDefaultsKeys.maxResponseTokens) as? Int ?? Int(LLMConstants.maxNewTokens)
        generationTimeout = defaults.object(forKey: UserDefaultsKeys.generationTimeout) as? Double ?? ChatConstants.generationTimeoutSeconds
        notesAccessEnabled = defaults.bool(forKey: UserDefaultsKeys.notesAccessEnabled)
        remindersAccessEnabled = defaults.bool(forKey: UserDefaultsKeys.remindersAccessEnabled)
        mailAccessEnabled = defaults.bool(forKey: UserDefaultsKeys.mailAccessEnabled)
        webSearchEnabled = defaults.bool(forKey: UserDefaultsKeys.webSearchEnabled)
        webSearchProvider = WebSearchProvider(rawValue: defaults.string(forKey: UserDefaultsKeys.webSearchProvider) ?? "") ?? .brave
        webSearchEndpoint = defaults.string(forKey: UserDefaultsKeys.webSearchEndpoint) ?? ""
        // Migrate key from UserDefaults → Keychain on first run after update.
        if let legacy = defaults.string(forKey: UserDefaultsKeys.braveApiKey), !legacy.isEmpty {
            Self.keychainSet(legacy, forKey: UserDefaultsKeys.braveApiKey)
            defaults.removeObject(forKey: UserDefaultsKeys.braveApiKey)
        }
        braveApiKey = Self.keychainGet(forKey: UserDefaultsKeys.braveApiKey) ?? ""
        locationEnabled = defaults.bool(forKey: UserDefaultsKeys.locationEnabled)
        userCity = defaults.string(forKey: UserDefaultsKeys.userCity) ?? ""
        visionEnabled = defaults.object(forKey: UserDefaultsKeys.visionEnabled) as? Bool ?? true
    }

    // MARK: - Computed Properties

    var selectedTextModel: ModelInfo {
        ModelInfo.available(physicalRAMGB: deviceRAMGB)
            .first { $0.id == selectedTextModelID }
            ?? ModelInfo.qwen3_5_2B
    }

    var selectedVisionModel: ModelInfo {
        ModelInfo.visionModels(physicalRAMGB: deviceRAMGB)
            .first { $0.id == selectedVisionModelID }
            ?? ModelInfo.qwen3_5_vision
    }

    var deviceRAMGB: Int {
        Int(ProcessInfo.processInfo.physicalMemory / Self.bytesPerGB)
    }

    var maxContextSize: Int {
        deviceRAMGB >= ChatConstants.largeContextRAMThresholdGB
            ? ChatConstants.largeContextSizeTokens
            : ChatConstants.tinyContextSizeTokens
    }

    // Backwards-compat alias for existing code that reads selectedModelID
    var selectedModelID: String {
        get { selectedTextModelID }
        set { selectedTextModelID = newValue }
    }

    // Backwards-compat alias for existing code that reads selectedModel
    var selectedModel: ModelInfo { selectedTextModel }

    // MARK: - Private Constants

    private static let bytesPerGB: UInt64 = 1_073_741_824

    // MARK: - Keychain Helpers

    private static func keychainGet(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func keychainSet(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key
        ]
        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            let update: [CFString: Any] = [kSecValueData: data]
            SecItemUpdate(query as CFDictionary, update as CFDictionary)
        } else {
            var item = query
            item[kSecValueData] = data
            item[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }
}
