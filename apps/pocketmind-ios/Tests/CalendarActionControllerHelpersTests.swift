@testable import PocketMind
import XCTest

@MainActor
final class CalendarActionControllerHelpersTests: XCTestCase {
    var mock: MockCalendarService!
    var settings: AppSettingsProtocol!
    var controller: CalendarActionController!

    override func setUp() async throws {
        try await super.setUp()
        mock = MockCalendarService()
        settings = MockAppSettings()
        controller = CalendarActionController(calendarService: mock, settings: settings)
    }

    // MARK: - makeConflictSnapshots

    func testMakeConflictSnapshotsEmptyInput() {
        let result = controller.makeConflictSnapshots(from: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testMakeConflictSnapshotsMapsTitle() {
        let event = MockCalendarService.makeConflict(
            title: "Team Meeting",
            start: Date(timeIntervalSinceNow: 0),
            end: Date(timeIntervalSinceNow: 3600)
        )
        let snapshots = controller.makeConflictSnapshots(from: [event])
        XCTAssertEqual(snapshots.count, 1)
        XCTAssertEqual(snapshots[0].title, "Team Meeting")
    }

    func testMakeConflictSnapshotsMapsNilTitleToDefault() {
        let event = CalendarEventInfo(
            eventIdentifier: "no-title",
            title: nil,
            startDate: Date(timeIntervalSinceNow: 0),
            endDate: Date(timeIntervalSinceNow: 3600),
            isAllDay: false,
            calendarTitle: "Work",
            isRecurring: false
        )
        let snapshots = controller.makeConflictSnapshots(from: [event])
        XCTAssertEqual(snapshots[0].title, "Event")
    }

    func testMakeConflictSnapshotsMapsIsRecurring() {
        let event = MockCalendarService.makeConflict(
            title: "Standup",
            start: Date(timeIntervalSinceNow: 0),
            end: Date(timeIntervalSinceNow: 1800),
            isRecurring: true
        )
        let snapshots = controller.makeConflictSnapshots(from: [event])
        XCTAssertTrue(snapshots[0].isRecurring)
    }

    func testMakeConflictSnapshotsPreservesOrder() {
        let events = ["Alpha", "Beta", "Gamma"].map {
            MockCalendarService.makeConflict(
                title: $0,
                start: Date(timeIntervalSinceNow: 0),
                end: Date(timeIntervalSinceNow: 3600)
            )
        }
        let snapshots = controller.makeConflictSnapshots(from: events)
        XCTAssertEqual(snapshots.map(\.title), ["Alpha", "Beta", "Gamma"])
    }

    // MARK: - mergeBusyWindows

    func testMergeBusyWindowsEmptyInput() {
        let result = controller.mergeBusyWindows(from: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testMergeBusyWindowsSingleEvent() {
        let start = Date(timeIntervalSinceNow: 0)
        let end = Date(timeIntervalSinceNow: 3600)
        let event = MockCalendarService.makeConflict(title: "A", start: start, end: end)
        let windows = controller.mergeBusyWindows(from: [event])
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows[0].start, start)
        XCTAssertEqual(windows[0].end, end)
    }

    func testMergeBusyWindowsNonOverlappingEventsRetainsBoth() {
        let e1 = MockCalendarService.makeConflict(
            title: "A",
            start: Date(timeIntervalSinceNow: 0),
            end: Date(timeIntervalSinceNow: 3600)
        )
        let e2 = MockCalendarService.makeConflict(
            title: "B",
            start: Date(timeIntervalSinceNow: 7200),
            end: Date(timeIntervalSinceNow: 10800)
        )
        let windows = controller.mergeBusyWindows(from: [e1, e2])
        XCTAssertEqual(windows.count, 2)
    }

    func testMergeBusyWindowsOverlappingEventsMergesIntoOne() {
        let e1 = MockCalendarService.makeConflict(
            title: "A",
            start: Date(timeIntervalSinceNow: 0),
            end: Date(timeIntervalSinceNow: 3600)
        )
        let e2 = MockCalendarService.makeConflict(
            title: "B",
            start: Date(timeIntervalSinceNow: 1800),
            end: Date(timeIntervalSinceNow: 5400)
        )
        let windows = controller.mergeBusyWindows(from: [e1, e2])
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows[0].end, Date(timeIntervalSinceNow: 5400))
    }

    func testMergeBusyWindowsContainedEventDoesNotShrinkWindow() {
        let outer = MockCalendarService.makeConflict(
            title: "Outer",
            start: Date(timeIntervalSinceNow: 0),
            end: Date(timeIntervalSinceNow: 7200)
        )
        let inner = MockCalendarService.makeConflict(
            title: "Inner",
            start: Date(timeIntervalSinceNow: 1000),
            end: Date(timeIntervalSinceNow: 2000)
        )
        let windows = controller.mergeBusyWindows(from: [outer, inner])
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows[0].end, Date(timeIntervalSinceNow: 7200))
    }

    func testMergeBusyWindowsMergesThreeChained() {
        let e1 = MockCalendarService.makeConflict(
            title: "A",
            start: Date(timeIntervalSinceNow: 0),
            end: Date(timeIntervalSinceNow: 2000)
        )
        let e2 = MockCalendarService.makeConflict(
            title: "B",
            start: Date(timeIntervalSinceNow: 1500),
            end: Date(timeIntervalSinceNow: 4000)
        )
        let e3 = MockCalendarService.makeConflict(
            title: "C",
            start: Date(timeIntervalSinceNow: 3500),
            end: Date(timeIntervalSinceNow: 6000)
        )
        let windows = controller.mergeBusyWindows(from: [e1, e2, e3])
        XCTAssertEqual(windows.count, 1)
        XCTAssertEqual(windows[0].end, Date(timeIntervalSinceNow: 6000))
    }
}
