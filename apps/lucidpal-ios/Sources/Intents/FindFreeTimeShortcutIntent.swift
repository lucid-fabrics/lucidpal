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
        // Direct EventKit access — CalendarService requires @MainActor but intents run off-main
        let store = EKEventStore()

        // Check authorization
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status == .fullAccess else {
            return .result(value: "", dialog: "Calendar access not granted. Please enable in Settings.")
        }

        // Search window: start of searchDate to 7 days later
        let cal = Calendar.current
        let rangeStart = cal.startOfDay(for: searchDate)
        let rangeEnd = cal.date(byAdding: .day, value: 7, to: rangeStart) ?? rangeStart

        // Fetch and merge busy events
        let predicate = store.predicateForEvents(withStart: rangeStart, end: rangeEnd, calendars: nil)
        let rawWindows = store.events(matching: predicate).map { (start: $0.startDate as Date, end: $0.endDate as Date) }
        let busyWindows = SiriCalendarBridge.mergeBusyWindows(rawWindows)

        // Delegate slot search to CalendarFreeSlotEngine via bridge
        let duration = TimeInterval(durationMinutes * 60)
        guard let slot = SiriCalendarBridge.findFirstFreeSlot(
            busyWindows: busyWindows,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            duration: duration
        ) else {
            return .result(value: "", dialog: "No free \(durationMinutes)-minute slots found in the next 7 days.")
        }

        let slotDesc = SiriCalendarBridge.formatSlot(start: slot.start)
        return .result(
            value: slotDesc,
            dialog: "Free slot: \(slotDesc) for \(durationMinutes) minutes."
        )
    }
}
