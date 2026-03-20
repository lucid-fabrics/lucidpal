import Foundation

/// Centralised UserDefaults key constants — prevents typos and duplicated literals.
enum UserDefaultsKeys {
    static let calendarAccessEnabled    = "calendarAccessEnabled"
    static let selectedModelID          = "selectedModelID"
    static let hasCompletedOnboarding   = "hasCompletedOnboarding"
    static let thinkingEnabled          = "thinkingEnabled"
    static let defaultCalendarIdentifier = "defaultCalendarIdentifier"
    static let speechAutoSendEnabled    = "speechAutoSendEnabled"

    static let siriPendingQuery         = "pm_siri_pending_query"
    static let siriPendingEvent         = "pm_siri_pending_event"

    static let suggestionsCache         = "pm_suggestions"
    static let suggestionsCacheDate     = "pm_suggestions_date"
}
