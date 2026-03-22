import Foundation

/// Pure logic helpers for Siri AppIntent handlers.
///
/// AppIntent structs are instantiated by the Siri framework and cannot use
/// dependency injection — EKEventStore access stays in the thin intent handlers,
/// while all pure (testable) logic lives here.
///
/// This separates the "how to query EventKit" (intent layer, untestable)
/// from "what to do with the data" (bridge layer, fully unit-testable).
enum SiriCalendarBridge {

    // MARK: - Event formatting

    /// Formats an event into a human-readable string for Siri dialog responses.
    static func formatEvent(title: String, start: Date, location: String?) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        let startStr = formatter.string(from: start)
        let locationPart = location.flatMap { $0.isEmpty ? nil : " at \($0)" } ?? ""
        return "\(title)\(locationPart) — \(startStr)"
    }

    /// Formats a free slot start time for Siri dialog responses.
    static func formatSlot(start: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: start)
    }

    // MARK: - Busy window merging

    /// Merges overlapping/adjacent busy windows into sorted non-overlapping intervals.
    static func mergeBusyWindows(_ windows: [(start: Date, end: Date)]) -> [(start: Date, end: Date)] {
        let sorted = windows.sorted { $0.start < $1.start }
        var merged: [(start: Date, end: Date)] = []
        for window in sorted {
            if let last = merged.last, window.start < last.end {
                merged[merged.count - 1] = (last.start, max(last.end, window.end))
            } else {
                merged.append(window)
            }
        }
        return merged
    }

    // MARK: - Free slot search

    /// Finds the first free slot of `duration` within `rangeStart..<rangeEnd`.
    /// Delegates to CalendarFreeSlotEngine (weekends skipped, 8 am–8 pm window enforced).
    static func findFirstFreeSlot(
        busyWindows: [(start: Date, end: Date)],
        rangeStart: Date,
        rangeEnd: Date,
        duration: TimeInterval
    ) -> (start: Date, end: Date)? {
        let slots = CalendarFreeSlotEngine.findSlots(
            busyWindows: busyWindows,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            duration: duration
        )
        guard let first = slots.first else { return nil }
        return (first.start, first.end)
    }
}
