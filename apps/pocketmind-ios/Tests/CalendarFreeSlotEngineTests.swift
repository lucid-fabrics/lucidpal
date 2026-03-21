import XCTest
@testable import PocketMind

@MainActor
final class CalendarFreeSlotEngineTests: XCTestCase {

    private func date(_ dayOffset: Int, hour: Int, minute: Int = 0) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        comps.day = (comps.day ?? 0) + dayOffset
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return Calendar.current.date(from: comps) ?? .now
    }

    private func nextMonday() -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        comps.weekday = 2  // Monday
        return cal.date(from: comps) ?? .now
    }

    func testNoEventsReturnsFreeWorkingSlots() {
        let monday = nextMonday()
        let rangeStart = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: monday)!
        let rangeEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: monday)!

        let slots = CalendarFreeSlotEngine.findSlots(
            busyWindows: [],
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            duration: 3600
        )
        XCTAssertFalse(slots.isEmpty, "Should find free slots on an empty weekday")
    }

    func testReturnsAtMostFiveSlots() {
        let monday = nextMonday()
        let rangeStart = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: monday)!
        let rangeEnd = Calendar.current.date(byAdding: .day, value: 5, to: rangeStart)!

        let slots = CalendarFreeSlotEngine.findSlots(
            busyWindows: [],
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            duration: 3600
        )
        XCTAssertLessThanOrEqual(slots.count, 5)
    }

    func testBusyWindowBlocksSlot() {
        let monday = nextMonday()
        let dayStart = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: monday)!
        let dayEnd = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: monday)!
        // Block entire working day
        let slots = CalendarFreeSlotEngine.findSlots(
            busyWindows: [(start: dayStart, end: dayEnd)],
            rangeStart: dayStart,
            rangeEnd: dayEnd,
            duration: 3600
        )
        XCTAssertTrue(slots.isEmpty, "Fully blocked day should return no slots")
    }

    func testDurationRequirementFiltersShortGaps() {
        let monday = nextMonday()
        let dayStart = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: monday)!
        // 30-minute gap at 9am
        let busyEnd = Calendar.current.date(bySettingHour: 9, minute: 30, second: 0, of: monday)!
        let busyStart2 = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: monday)!
        let dayEnd = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: monday)!

        let slots = CalendarFreeSlotEngine.findSlots(
            busyWindows: [
                (start: dayStart, end: busyEnd),
                (start: busyStart2, end: dayEnd)
            ],
            rangeStart: dayStart,
            rangeEnd: dayEnd,
            duration: 3600  // require 1 hour
        )
        XCTAssertTrue(slots.isEmpty, "30-minute gap should not satisfy 1-hour duration requirement")
    }

    func testDSTTransitionDoesNotProduceInvalidSlots() {
        // Build a range that straddles a DST boundary using a fixed UTC offset calendar
        // so the test is repeatable regardless of current date.
        // We simulate a 23-hour day (spring-forward) by constructing the range manually
        // from absolute TimeIntervals, then verify engine still returns valid ordered slots.
        let springForward = Date(timeIntervalSince1970: 1_710_054_000) // 2024-03-10 07:00 UTC (2am ET spring-forward)
        let rangeStart = springForward
        let rangeEnd = springForward.addingTimeInterval(23 * 3600) // 23h day

        let slots = CalendarFreeSlotEngine.findSlots(
            busyWindows: [],
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            duration: 3600
        )
        for slot in slots {
            XCTAssertLessThan(slot.start, slot.end, "DST transition slot must have start < end")
            XCTAssertGreaterThanOrEqual(slot.start, rangeStart, "Slot must not start before range")
            XCTAssertLessThanOrEqual(slot.end, rangeEnd, "Slot must not end after range")
        }
    }

    func testSlotStartAndEndAreOrdered() {
        let monday = nextMonday()
        let rangeStart = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: monday)!
        let rangeEnd = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: monday)!

        let slots = CalendarFreeSlotEngine.findSlots(
            busyWindows: [],
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            duration: 3600
        )
        for slot in slots {
            XCTAssertLessThan(slot.start, slot.end, "Slot start must be before end")
        }
    }

    func testWeekendDaysAreSkipped() {
        // Range spanning an entire week — engine must not emit slots on Sat/Sun
        let monday = nextMonday()
        let rangeStart = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: monday)!
        let rangeEnd = Calendar.current.date(byAdding: .day, value: 7, to: rangeStart)!

        let slots = CalendarFreeSlotEngine.findSlots(
            busyWindows: [],
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            duration: 3600
        )
        let cal = Calendar.current
        for slot in slots {
            let weekday = cal.component(.weekday, from: slot.start)
            XCTAssertFalse([1, 7].contains(weekday), "Slots must not fall on weekends (weekday=\(weekday))")
        }
    }

    func testOverlappingBusyWindowsAreHandled() {
        // Two events that overlap — engine must not crash and must skip the combined window
        let monday = nextMonday()
        let busyStart = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: monday)!
        let busyMid   = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: monday)!
        let busyEnd   = Calendar.current.date(bySettingHour: 11, minute: 0, second: 0, of: monday)!
        let rangeEnd  = Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: monday)!

        let slots = CalendarFreeSlotEngine.findSlots(
            busyWindows: [
                (start: busyStart, end: busyEnd),
                (start: busyMid,   end: busyEnd)   // overlaps first
            ],
            rangeStart: busyStart,
            rangeEnd: rangeEnd,
            duration: 3600
        )
        for slot in slots {
            XCTAssertGreaterThanOrEqual(slot.start, busyEnd, "Slot must start after the merged busy window")
        }
    }

    func testDurationLongerThanWorkDayReturnsEmpty() {
        // Requesting a 13-hour slot (longer than 8am–8pm window) must never match
        let monday = nextMonday()
        let rangeStart = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: monday)!
        let rangeEnd   = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: monday)!

        let slots = CalendarFreeSlotEngine.findSlots(
            busyWindows: [],
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            duration: 13 * 3600
        )
        XCTAssertTrue(slots.isEmpty, "No slot should fit a 13-hour duration in an 8am–8pm window")
    }

    func testConsecutiveMeetingsLeaveNoGap() {
        // Back-to-back 1-hour meetings fill the whole day — no 1-hour slot should exist
        let monday = nextMonday()
        let cal = Calendar.current
        var windows: [(start: Date, end: Date)] = []
        var cursor = cal.date(bySettingHour: 8, minute: 0, second: 0, of: monday)!
        let dayEnd  = cal.date(bySettingHour: 20, minute: 0, second: 0, of: monday)!
        while cursor < dayEnd {
            let next = cursor.addingTimeInterval(3600)
            windows.append((start: cursor, end: min(next, dayEnd)))
            cursor = next
        }

        let slots = CalendarFreeSlotEngine.findSlots(
            busyWindows: windows,
            rangeStart: cal.date(bySettingHour: 8, minute: 0, second: 0, of: monday)!,
            rangeEnd: dayEnd,
            duration: 3600
        )
        XCTAssertTrue(slots.isEmpty, "Back-to-back meetings should leave no free slot")
    }

    func testZeroDurationRangeReturnsEmpty() {
        let monday = nextMonday()
        let point = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: monday)!

        let slots = CalendarFreeSlotEngine.findSlots(
            busyWindows: [],
            rangeStart: point,
            rangeEnd: point,
            duration: 3600
        )
        XCTAssertTrue(slots.isEmpty, "Zero-length range must return no slots")
    }

    func testSlotsDoNotExceedWorkingHours() {
        // Even with an empty calendar, slots must stay within 8am–8pm
        let monday = nextMonday()
        let rangeStart = Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: monday)!
        let rangeEnd   = Calendar.current.date(bySettingHour: 23, minute: 59, second: 0, of: monday)!

        let slots = CalendarFreeSlotEngine.findSlots(
            busyWindows: [],
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            duration: 3600
        )
        let cal = Calendar.current
        for slot in slots {
            let startHour = cal.component(.hour, from: slot.start)
            let endHour   = cal.component(.hour, from: slot.end)
            let endMin    = cal.component(.minute, from: slot.end)
            XCTAssertGreaterThanOrEqual(startHour, 8, "Slot must not start before 8am")
            XCTAssertTrue(endHour < 20 || (endHour == 20 && endMin == 0), "Slot must not end after 8pm")
        }
    }
}
