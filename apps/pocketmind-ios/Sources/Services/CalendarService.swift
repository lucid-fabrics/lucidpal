import EventKit
import Foundation

// CalendarService is a pure data-access service — it holds no observable UI state.
// SettingsViewModel owns @Published calendarAuthStatus and syncs it manually after
// requestAccess() returns, keeping the observable layer entirely in ViewModels.
@MainActor
final class CalendarService {
    // nonisolated(unsafe): EKEventStore is documented as thread-safe for read operations.
    // Marking it nonisolated(unsafe) allows background query offloading below.
    nonisolated(unsafe) private let store = EKEventStore()

    private(set) var authorizationStatus: EKAuthorizationStatus = .notDetermined

    // Reuse formatter — DateFormatter is expensive to construct
    private static let eventFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    func requestAccess() async -> Bool {
        do {
            let granted: Bool
            if #available(iOS 17.0, *) {
                granted = try await store.requestFullAccessToEvents()
            } else {
                granted = try await store.requestAccess(to: .event)
            }
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
            return granted
        } catch {
            return false
        }
    }

    var isAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            return authorizationStatus == .authorized
        }
    }

    /// Fetches events and formats them as a prompt-ready string.
    /// - Refreshes authorization status on every call to detect runtime revocation.
    /// - Caps at 50 events to prevent LLM context overflow.
    /// - Runs the EKEventStore query on a background thread (EKEventStore is thread-safe).
    func fetchEvents(from start: Date = .now, days: Int = 7) async -> String {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        guard isAuthorized else { return "" }

        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [store, predicate, days] in
                let events = store.events(matching: predicate)
                    .sorted { $0.startDate < $1.startDate }
                    .prefix(50)

                let result: String
                if events.isEmpty {
                    result = "No events in the next \(days) days."
                } else {
                    result = events.map { CalendarService.formatEvent($0) }.joined(separator: "\n")
                }
                continuation.resume(returning: result)
            }
        }
    }

    private static func formatEvent(_ event: EKEvent) -> String {
        let start = eventFormatter.string(from: event.startDate)
        let end = eventFormatter.string(from: event.endDate)
        let title = event.title ?? "Untitled"
        let cal = event.calendar?.title ?? ""
        let location = event.location.map { " @ \($0)" } ?? ""
        return "- \(title)\(location): \(start) → \(end) [\(cal)]"
    }
}
