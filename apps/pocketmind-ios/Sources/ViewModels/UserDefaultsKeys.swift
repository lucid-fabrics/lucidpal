import Foundation

/// Centralised UserDefaults key constants — prevents typos and duplicated literals.
enum UserDefaultsKeys {
    static let calendarAccessEnabled    = "calendarAccessEnabled"
    static let selectedModelID          = "selectedModelID"
    static let hasCompletedOnboarding   = "hasCompletedOnboarding"
    static let thinkingEnabled          = "thinkingEnabled"
    static let defaultCalendarIdentifier = "defaultCalendarIdentifier"
    static let speechAutoSendEnabled    = "speechAutoSendEnabled"
    static let voiceAutoStartEnabled    = "voiceAutoStartEnabled"
    static let airpodsAutoVoiceEnabled  = "airpodsAutoVoiceEnabled"
    static let contextSize              = "contextSize"
    static let notesAccessEnabled       = "notesAccessEnabled"
    static let remindersAccessEnabled   = "remindersAccessEnabled"
    static let mailAccessEnabled        = "mailAccessEnabled"
    static let webSearchEnabled         = "webSearchEnabled"
    static let webSearchProvider        = "webSearchProvider"
    static let webSearchEndpoint        = "webSearchEndpoint"
    static let braveApiKey              = "braveApiKey"
    static let locationEnabled          = "locationEnabled"
    static let userCity                 = "userCity"

    static let siriPendingQuery         = "pm_siri_pending_query"
    static let siriPendingEvent         = "pm_siri_pending_event"
    static let siriLastAction           = "pm_siri_last_action"

    static let suggestionsCache         = "pm_suggestions"
    static let suggestionsCacheDate     = "pm_suggestions_date"
}
