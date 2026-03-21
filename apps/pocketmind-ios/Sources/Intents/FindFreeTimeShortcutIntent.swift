import AppIntents
import EventKit
import Foundation

/// Shortcuts-compatible intent — finds free time slots and returns the first available one.
/// Unlike FindFreeTimeIntent (which opens the app), this runs in background.
struct FindFreeTimeShortcutIntent: AppIntent {

    static let title: LocalizedStringResource = "Find Free Time"
    static let description = IntentDescription("Find available time slots in your calendar")
    static let openAppWhenRun: Bool = false

    @Parameter(title: "Date",
               description: "Search for free time on this date",
               default: Date.now)
    var searchDate: Date

    @Parameter(title: "Duration (minutes)",
               description: "Required length of the free slot",
               default: 60)
    var durationMinutes: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Find \(\.$durationMinutes) minutes of free time on \(\.$searchDate)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let store = EKEventStore()

        // Check authorization
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess else {
            return .result(value: "", dialog: "Calendar access not granted. Please enable in Settings.")
        }

        // Search window: start of searchDate to 7 days later
        let cal = Calendar.current
        var startComps = cal.dateComponents([.year, .month, .day], from: searchDate)
        startComps.hour = 0; startComps.minute = 0; startComps.second = 0
        let rangeStart = cal.date(from: startComps) ?? searchDate
        let rangeEnd = cal.date(byAdding: .day, value: 7, to: rangeStart) ?? rangeStart

        // Fetch busy events
        let predicate = store.predicateForEvents(withStart: rangeStart, end: rangeEnd, calendars: nil)
        let busyEvents = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        // Merge overlapping events
        var busyWindows: [(start: Date, end: Date)] = []
        for event in busyEvents {
            if let last = busyWindows.last, event.startDate < last.end {
                busyWindows[busyWindows.count - 1].end = max(last.end, event.endDate)
            } else {
                busyWindows.append((start: event.startDate, end: event.endDate))
            }
        }

        // Find free slots (simplified working hours: 8am-8pm, Mon-Fri)
        let duration = TimeInterval(durationMinutes * 60)
        var cursor = rangeStart
        var freeSlot: (start: Date, end: Date)?

        while cursor < rangeEnd && freeSlot == nil {
            // Skip weekends
            let weekday = cal.component(.weekday, from: cursor)
            if weekday == 1 || weekday == 7 {
                cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? rangeEnd
                continue
            }

            // Working day: 8am-8pm
            var dayStart = cal.dateComponents([.year, .month, .day], from: cursor)
            dayStart.hour = 8; dayStart.minute = 0
            let workStart = cal.date(from: dayStart) ?? cursor

            var dayEnd = cal.dateComponents([.year, .month, .day], from: cursor)
            dayEnd.hour = 20; dayEnd.minute = 0
            let workEnd = cal.date(from: dayEnd) ?? cursor

            // Check if this time window is free
            var candidateStart = max(workStart, cursor)
            let candidateEnd = candidateStart.addingTimeInterval(duration)

            if candidateEnd <= workEnd {
                let conflicts = busyWindows.filter { busy in
                    busy.start < candidateEnd && busy.end > candidateStart
                }
                if conflicts.isEmpty {
                    freeSlot = (candidateStart, candidateEnd)
                } else {
                    // Move cursor past the conflict
                    cursor = conflicts.first?.end ?? candidateEnd
                    continue
                }
            }

            // Move to next day if no slot found
            if freeSlot == nil {
                cursor = cal.date(byAdding: .day, value: 1, to: cursor) ?? rangeEnd
            }
        }

        guard let slot = freeSlot else {
            return .result(value: "", dialog: "No free \(durationMinutes)-minute slots found in the next 7 days.")
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let slotDesc = formatter.string(from: slot.start)

        return .result(
            value: slotDesc,
            dialog: "Free slot: \(slotDesc) for \(durationMinutes) minutes."
        )
    }
}
