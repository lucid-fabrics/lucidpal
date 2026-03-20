import Foundation

// MARK: - CalendarActionController private helpers
// Extracted to keep CalendarActionController.swift under 300 lines.

extension CalendarActionController {

    /// Maps an array of `CalendarEventInfo` values to `ConflictingEventSnapshot` values.
    func makeConflictSnapshots(from events: [CalendarEventInfo]) -> [ConflictingEventSnapshot] {
        events.map {
            ConflictingEventSnapshot(
                title: $0.title ?? "Event",
                start: $0.startDate,
                end: $0.endDate,
                calendarName: $0.calendarTitle,
                isRecurring: $0.isRecurring,
                isAllDay: $0.isAllDay
            )
        }
    }

    /// Merges overlapping busy windows from a sorted list of calendar events.
    /// Events must be pre-sorted by `startDate` ascending.
    func mergeBusyWindows(from events: [CalendarEventInfo]) -> [(start: Date, end: Date)] {
        var merged: [(start: Date, end: Date)] = []
        for ev in events {
            let window = (start: ev.startDate, end: ev.endDate)
            if let last = merged.last, window.start < last.end {
                merged[merged.count - 1] = (last.start, max(last.end, window.end))
            } else {
                merged.append(window)
            }
        }
        return merged
    }
}
