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
        guard duration > 0, rangeStart < rangeEnd else { return [] }
        var freeSlots: [CalendarFreeSlot] = []
        var cursor = nextWeekdayStart(from: rangeStart)
        var busyIdx = 0

        while cursor < rangeEnd && freeSlots.count < 5 {
            // Skip weekends (nextWeekdayStart handles them, but guard against drift)
            if isWeekend(cursor) {
                cursor = nextWeekdayStart(from: cursor)
                continue
            }

            let workEnd = workDayEnd(from: cursor)

            // Advance past busy windows that have already ended
            while busyIdx < busyWindows.count && busyWindows[busyIdx].end <= cursor {
                busyIdx += 1
            }

            let nextBusyStart = busyIdx < busyWindows.count ? busyWindows[busyIdx].start : rangeEnd
            let freeUntil = min(nextBusyStart, workEnd)

            if freeUntil > cursor && freeUntil.timeIntervalSince(cursor) >= duration {
                let slotEnd = cursor.addingTimeInterval(duration)
                freeSlots.append(CalendarFreeSlot(start: cursor, end: slotEnd))
                cursor = slotEnd
            } else if busyIdx < busyWindows.count && busyWindows[busyIdx].start < workEnd {
                cursor = nextWeekdayStart(from: busyWindows[busyIdx].end)
                busyIdx += 1
            } else {
                let cal = Calendar.current
                cursor = nextWeekdayStart(from: cal.date(byAdding: .day, value: 1, to: workEnd) ?? workEnd)
            }
        }
        return freeSlots
    }

    // MARK: - Helpers

    /// Returns the start of the next weekday working window (8 AM) at or after `from`.
    private static func nextWeekdayStart(from date: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = 8; comps.minute = 0; comps.second = 0
        var candidate = cal.date(from: comps) ?? date
        if candidate < date {
            candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        var safetyLimit = 8
        while isWeekend(candidate) && safetyLimit > 0 {
            safetyLimit -= 1
            candidate = cal.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    /// Returns the end-of-workday time for the day containing `date`.
    private static func workDayEnd(from date: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = ChatConstants.defaultWorkdayEndHour; comps.minute = 0; comps.second = 0
        return cal.date(from: comps) ?? date
    }

    /// Saturday (7) or Sunday (1) in the Gregorian calendar.
    private static func isWeekend(_ date: Date) -> Bool {
        [1, 7].contains(Calendar.current.component(.weekday, from: date))
    }
}
