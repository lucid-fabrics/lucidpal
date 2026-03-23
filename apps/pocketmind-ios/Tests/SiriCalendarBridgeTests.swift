@testable import PocketMind
import XCTest

@MainActor
final class SiriCalendarBridgeTests: XCTestCase {

    // MARK: - formatEvent

    func testFormatEventIncludesTitle() {
        let result = SiriCalendarBridge.formatEvent(title: "Standup", start: .now, location: nil)
        XCTAssertTrue(result.contains("Standup"))
    }

    func testFormatEventIncludesLocation() {
        let result = SiriCalendarBridge.formatEvent(title: "Lunch", start: .now, location: "Café")
        XCTAssertTrue(result.contains("at Café"))
    }

    func testFormatEventOmitsEmptyLocation() {
        let result = SiriCalendarBridge.formatEvent(title: "Call", start: .now, location: "")
        XCTAssertFalse(result.contains("at "))
    }

    func testFormatEventOmitsNilLocation() {
        let result = SiriCalendarBridge.formatEvent(title: "Call", start: .now, location: nil)
        XCTAssertFalse(result.contains("at "))
    }

    // MARK: - formatSlot

    func testFormatSlotIsNonEmpty() {
        XCTAssertFalse(SiriCalendarBridge.formatSlot(start: .now).isEmpty)
    }

    // MARK: - mergeBusyWindows

    func testMergeEmptyWindowsReturnsEmpty() {
        XCTAssertTrue(SiriCalendarBridge.mergeBusyWindows([]).isEmpty)
    }

    func testMergeNonOverlappingWindowsPreservesAll() {
        let now = Date.now
        let w1 = (start: now, end: now.addingTimeInterval(3600))
        let w2 = (start: now.addingTimeInterval(7200), end: now.addingTimeInterval(10800))
        let merged = SiriCalendarBridge.mergeBusyWindows([w1, w2])
        XCTAssertEqual(merged.count, 2)
    }

    func testMergeOverlappingWindowsCombinesIntoOne() {
        let now = Date.now
        let w1 = (start: now, end: now.addingTimeInterval(3600))
        let w2 = (start: now.addingTimeInterval(1800), end: now.addingTimeInterval(5400))
        let merged = SiriCalendarBridge.mergeBusyWindows([w1, w2])
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].start, now)
        XCTAssertEqual(merged[0].end, now.addingTimeInterval(5400))
    }

    func testMergeAdjacentWindowsKeepsSeparate() {
        let now = Date.now
        let w1 = (start: now, end: now.addingTimeInterval(3600))
        let w2 = (start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200))
        let merged = SiriCalendarBridge.mergeBusyWindows([w1, w2])
        XCTAssertEqual(merged.count, 2)
    }

    func testMergeReturnsResultsSortedByStart() {
        let now = Date.now
        let w1 = (start: now.addingTimeInterval(3600), end: now.addingTimeInterval(7200))
        let w2 = (start: now, end: now.addingTimeInterval(1800))
        let merged = SiriCalendarBridge.mergeBusyWindows([w1, w2])
        XCTAssertEqual(merged.count, 2)
        XCTAssertLessThan(merged[0].start, merged[1].start)
    }

    // MARK: - findFirstFreeSlot

    func testFindFirstFreeSlotReturnsNilWhenFullyBlocked() {
        let monday = nextMonday()
        let cal = Calendar.current
        let dayStart = cal.date(bySettingHour: 0, minute: 0, second: 0, of: monday) ?? monday
        let dayEnd = cal.date(bySettingHour: 23, minute: 59, second: 0, of: monday) ?? monday
        // Block entire day
        let result = SiriCalendarBridge.findFirstFreeSlot(
            busyWindows: [(start: dayStart, end: dayEnd)],
            rangeStart: dayStart,
            rangeEnd: dayEnd,
            duration: 3600
        )
        XCTAssertNil(result)
    }

    func testFindFirstFreeSlotReturnsSlotOnEmptyDay() throws {
        let monday = nextMonday()
        let cal = Calendar.current
        let rangeStart = cal.date(bySettingHour: 0, minute: 0, second: 0, of: monday) ?? monday
        let rangeEnd = cal.date(bySettingHour: 23, minute: 59, second: 0, of: monday) ?? monday
        let result = SiriCalendarBridge.findFirstFreeSlot(
            busyWindows: [],
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            duration: 3600
        )
        let slot = try XCTUnwrap(result, "Expected a free slot on an empty day")
        XCTAssertLessThan(slot.start, slot.end)
    }

    func testFindFirstFreeSlotEndAfterStart() {
        let monday = nextMonday()
        let cal = Calendar.current
        let rangeStart = cal.date(bySettingHour: 0, minute: 0, second: 0, of: monday) ?? monday
        let rangeEnd = cal.date(byAdding: .day, value: 7, to: rangeStart) ?? rangeStart
        let result = SiriCalendarBridge.findFirstFreeSlot(
            busyWindows: [],
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            duration: 3600
        )
        if let slot = result {
            XCTAssertLessThan(slot.start, slot.end)
            XCTAssertEqual(slot.end.timeIntervalSince(slot.start), 3600, accuracy: 1)
        }
    }

    // MARK: - Helpers

    private func nextMonday() -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        comps.weekday = 2
        return cal.date(from: comps) ?? .now
    }
}
