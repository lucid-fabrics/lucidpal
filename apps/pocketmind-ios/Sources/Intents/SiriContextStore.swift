import Foundation
import OSLog

private let contextStoreLogger = Logger(subsystem: "com.pocketmind", category: "SiriContextStore")

/// Snapshot of the most recent calendar action taken in PocketMind — in-app or via Siri.
/// Persisted to UserDefaults so Siri intents always have context without opening the app.
struct SiriLastAction: Codable, Sendable {
    enum ActionType: String, Codable, Sendable {
        case created
        case deleted
        case updated
        case rescheduled
    }

    let type: ActionType
    let eventTitle: String
    let eventStart: Date
    let eventEnd: Date
    let calendarName: String?
    /// EKCalendar identifier — used to restore deleted events to their original calendar.
    let calendarIdentifier: String?
    let isAllDay: Bool
    let location: String?
    let notes: String?
    /// EKEvent identifier — populated for created events so Siri can delete on undo.
    let eventIdentifier: String?
    let timestamp: Date
}

/// Write-through UserDefaults cache for the last Siri-relevant action.
/// No App Group required: App Intents in the main target share UserDefaults.standard.
enum SiriContextStore {
    static func write(_ action: SiriLastAction) {
        do {
            let data = try JSONEncoder().encode(action)
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.siriLastAction)
        } catch {
            contextStoreLogger.error("SiriContextStore write failed: \(error)")
        }
    }

    static func read() -> SiriLastAction? {
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.siriLastAction) else { return nil }
        do {
            return try JSONDecoder().decode(SiriLastAction.self, from: data)
        } catch {
            contextStoreLogger.error("SiriContextStore read failed: \(error)")
            return nil
        }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.siriLastAction)
    }
}
