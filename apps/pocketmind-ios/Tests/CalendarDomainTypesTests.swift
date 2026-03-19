import XCTest
@testable import PocketMind

@MainActor
final class CalendarDomainTypesTests: XCTestCase {

    // MARK: - CalendarEventInfo

    func testCalendarEventInfoProperties() {
        let start = Date(timeIntervalSince1970: 1_000_000)
        let end   = Date(timeIntervalSince1970: 1_003_600)
        let event = CalendarEventInfo(
            eventIdentifier: "evt-1",
            title: "Meeting",
            startDate: start,
            endDate: end,
            isAllDay: false,
            calendarTitle: "Work"
        )
        XCTAssertEqual(event.eventIdentifier, "evt-1")
        XCTAssertEqual(event.title, "Meeting")
        XCTAssertEqual(event.startDate, start)
        XCTAssertEqual(event.endDate, end)
        XCTAssertFalse(event.isAllDay)
        XCTAssertEqual(event.calendarTitle, "Work")
    }

    func testCalendarEventInfoWithNilOptionals() {
        let event = CalendarEventInfo(
            eventIdentifier: nil,
            title: nil,
            startDate: .now,
            endDate: .now,
            isAllDay: true,
            calendarTitle: nil
        )
        XCTAssertNil(event.eventIdentifier)
        XCTAssertNil(event.title)
        XCTAssertNil(event.calendarTitle)
        XCTAssertTrue(event.isAllDay)
    }

    // MARK: - CalendarAuthorizationStatus

    func testCalendarAuthorizationStatusEquality() {
        XCTAssertEqual(CalendarAuthorizationStatus.notDetermined, .notDetermined)
        XCTAssertEqual(CalendarAuthorizationStatus.fullAccess, .fullAccess)
        XCTAssertEqual(CalendarAuthorizationStatus.denied, .denied)
        XCTAssertEqual(CalendarAuthorizationStatus.restricted, .restricted)
        XCTAssertEqual(CalendarAuthorizationStatus.writeOnly, .writeOnly)
        XCTAssertNotEqual(CalendarAuthorizationStatus.fullAccess, .denied)
    }

    func testCalendarAuthorizationStatusHasFiveCases() {
        let statuses: [CalendarAuthorizationStatus] = [.notDetermined, .restricted, .denied, .fullAccess, .writeOnly]
        XCTAssertEqual(statuses.count, 5)
    }

    // MARK: - CalendarInfo

    func testCalendarInfoIDAndTitle() {
        let info = CalendarInfo(id: "cal-1", title: "Personal")
        XCTAssertEqual(info.id, "cal-1")
        XCTAssertEqual(info.title, "Personal")
    }

    func testCalendarInfoHashable() {
        let a = CalendarInfo(id: "x", title: "A")
        let b = CalendarInfo(id: "x", title: "A")
        XCTAssertEqual(a, b)
        var set = Set<CalendarInfo>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - DownloadState

    func testDownloadStateIdleEquality() {
        XCTAssertEqual(DownloadState.idle, .idle)
    }

    func testDownloadStateDownloadingEquality() {
        XCTAssertEqual(DownloadState.downloading(progress: 0.5), .downloading(progress: 0.5))
        XCTAssertNotEqual(DownloadState.downloading(progress: 0.5), .downloading(progress: 1.0))
    }

    func testDownloadStateCompletedEquality() {
        let url = URL(fileURLWithPath: "/tmp/model.gguf")
        XCTAssertEqual(DownloadState.completed(url: url), .completed(url: url))
    }

    func testDownloadStateFailedEquality() {
        XCTAssertEqual(DownloadState.failed(message: "err"), .failed(message: "err"))
        XCTAssertNotEqual(DownloadState.failed(message: "a"), .failed(message: "b"))
    }

    func testDownloadStateNotEqualAcrossVariants() {
        XCTAssertNotEqual(DownloadState.idle, .downloading(progress: 0))
        XCTAssertNotEqual(DownloadState.idle, .failed(message: "x"))
    }
}
