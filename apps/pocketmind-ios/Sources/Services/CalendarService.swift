import EventKit
import Foundation

@MainActor
final class CalendarService: ObservableObject {
    private let store = EKEventStore()
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined

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

    /// Fetches events in the given range and formats them as a prompt-ready string.
    func fetchEvents(from start: Date = .now, days: Int = 7) -> String {
        guard isAuthorized else { return "" }

        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }

        guard !events.isEmpty else {
            return "No events in the next \(days) days."
        }

        let lines = events.map { event -> String in
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let start = formatter.string(from: event.startDate)
            let end = formatter.string(from: event.endDate)
            let title = event.title ?? "Untitled"
            let cal = event.calendar?.title ?? ""
            let location = event.location.map { " @ \($0)" } ?? ""
            return "- \(title)\(location): \(start) → \(end) [\(cal)]"
        }

        return lines.joined(separator: "\n")
    }
}
