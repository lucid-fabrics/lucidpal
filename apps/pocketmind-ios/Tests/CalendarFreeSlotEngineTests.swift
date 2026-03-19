import XCTest
@testable import PocketMind

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
}
