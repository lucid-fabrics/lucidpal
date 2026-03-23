import Foundation

// Pure slot-finding algorithm — no external dependencies.
// Used by CalendarActionController.findFreeSlots(_:).
enum CalendarFreeSlotEngine {

    /// Returns up to 5 free time slots of at least `duration` length within working hours (8am–8pm, Mon–Fri).
    /// - Parameters:
    ///   - busyWindows: Sorted, pre-merged busy intervals from the user's calendar.
    ///   - rangeStart: Start of the search window.
    ///   - rangeEnd: End of the search window.
    ///   - duration: Minimum length of a free slot.
    static func findSlots(
        busyWindows: [(start: Date, end: Date)],
        rangeStart: Date,
        rangeEnd: Date,
        duration: TimeInterval
    ) -> [CalendarFreeSlot] {
        let cal = Calendar.current

        func nextWeekdayStart(_ from: Date) -> Date {
            var comps = cal.dateComponents([.year, .month, .day], from: from)
            comps.hour = 8; comps.minute = 0; comps.second = 0
            var candidate = cal.date(from: comps) ?? from
            if candidate < from {
                candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            }
            // Skip Saturday (7) and Sunday (1)
            while [1, 7].contains(cal.component(.weekday, from: candidate)) {
                candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
            }
            return candidate
        }

        func workDayEnd(_ from: Date) -> Date {
            var comps = cal.dateComponents([.year, .month, .day], from: from)
            comps.hour = ChatConstants.defaultWorkdayEndHour; comps.minute = 0; comps.second = 0
            return cal.date(from: comps) ?? from
        }

        var freeSlots: [CalendarFreeSlot] = []
        var cursor = nextWeekdayStart(rangeStart)
        var busyIdx = 0

        while cursor < rangeEnd && freeSlots.count < 5 {
            // Skip weekends (nextWeekdayStart handles them, but guard against drift)
            if [1, 7].contains(cal.component(.weekday, from: cursor)) {
                cursor = nextWeekdayStart(cursor)
                continue
            }

            let workEnd = workDayEnd(cursor)

            // Advance past busy windows that have already ended
            while busyIdx < busyWindows.count && busyWindows[busyIdx].end <= cursor {
                busyIdx += 1
            }

            let nextBusyStart = busyIdx < busyWindows.count ? busyWindows[busyIdx].start : rangeEnd
            let freeUntil = min(nextBusyStart, workEnd)

            if freeUntil > cursor && freeUntil.timeIntervalSince(cursor) >= duration {
                // Slot fits — emit exactly `duration` long and advance cursor within the same gap
                let slotEnd = cursor.addingTimeInterval(duration)
                freeSlots.append(CalendarFreeSlot(start: cursor, end: slotEnd))
                cursor = slotEnd
            } else if busyIdx < busyWindows.count && busyWindows[busyIdx].start < workEnd {
                // Blocked by a busy window before end of work day — skip past it
                cursor = nextWeekdayStart(busyWindows[busyIdx].end)
                busyIdx += 1
            } else {
                // Reached end of work day — advance to next weekday morning
                cursor = nextWeekdayStart(cal.date(byAdding: .day, value: 1, to: workEnd) ?? workEnd)
            }
        }
        return freeSlots
    }
}
