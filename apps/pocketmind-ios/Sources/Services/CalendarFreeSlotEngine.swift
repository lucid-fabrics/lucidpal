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

        func nextWorkStart(_ from: Date) -> Date {
            var comps = cal.dateComponents([.year, .month, .day], from: from)
            comps.hour = 8; comps.minute = 0; comps.second = 0
            let day8am = cal.date(from: comps) ?? from
            return day8am < from ? cal.date(byAdding: .day, value: 1, to: day8am) ?? from : day8am
        }
        func dayEnd(_ from: Date) -> Date {
            var comps = cal.dateComponents([.year, .month, .day], from: from)
            comps.hour = 20; comps.minute = 0; comps.second = 0
            return cal.date(from: comps) ?? from
        }

        var cursor = nextWorkStart(rangeStart)
        var freeSlots: [CalendarFreeSlot] = []

        for window in busyWindows + [(rangeEnd, rangeEnd)] {
            guard cursor < rangeEnd else { break }
            let weekday = cal.component(.weekday, from: cursor)
            if weekday == 1 || weekday == 7 {
                cursor = nextWorkStart(cal.date(byAdding: .day, value: 1, to: cursor) ?? cursor)
                continue
            }
            let freeEnd = min(window.start, dayEnd(cursor))
            if freeEnd > cursor && freeEnd.timeIntervalSince(cursor) >= duration {
                freeSlots.append(CalendarFreeSlot(start: cursor, end: freeEnd))
                if freeSlots.count == 5 { break }
            }
            let afterBusy = window.end
            cursor = max(cursor, max(afterBusy, nextWorkStart(afterBusy)))
        }
        return freeSlots
    }
}
