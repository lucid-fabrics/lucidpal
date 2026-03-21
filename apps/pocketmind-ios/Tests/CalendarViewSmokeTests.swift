import XCTest
import SwiftUI
@testable import PocketMind

/// Smoke tests for calendar-specific and secondary view structs.
@MainActor
final class CalendarViewSmokeTests: XCTestCase {

    // MARK: - Shared test data

    private var previewCreated: CalendarEventPreview {
        CalendarEventPreview(
            title: "Team Meeting",
            start: Date(timeIntervalSinceNow: 3600),
            end: Date(timeIntervalSinceNow: 7200),
            calendarName: "Work",
            state: .created,
            eventIdentifier: "evt-001"
        )
    }

    private var previewPendingDeletion: CalendarEventPreview {
        CalendarEventPreview(
            title: "Dentist",
            start: Date(timeIntervalSinceNow: 7200),
            end: Date(timeIntervalSinceNow: 10800),
            calendarName: "Personal",
            state: .pendingDeletion,
            eventIdentifier: "evt-002"
        )
    }

    // MARK: - SuggestedPromptsView

    func testSuggestedPromptsViewCapturesPrompts() {
        let prompts = ["What's on my calendar?", "Add a meeting"]
        let view = SuggestedPromptsView(prompts: prompts, isLoading: false, onSelect: { _ in })
        XCTAssertEqual(view.prompts.count, 2)
        XCTAssertEqual(view.prompts.first, "What's on my calendar?")
        XCTAssertFalse(view.isLoading)
    }

    func testSuggestedPromptsViewLoadingState() {
        let view = SuggestedPromptsView(prompts: [], isLoading: true, onSelect: { _ in })
        XCTAssertTrue(view.isLoading)
        XCTAssertTrue(view.prompts.isEmpty)
    }

    func testSuggestedPromptsViewOnSelectFires() {
        var received = ""
        let view = SuggestedPromptsView(prompts: ["Test"], isLoading: false, onSelect: { received = $0 })
        view.onSelect("Test")
        XCTAssertEqual(received, "Test")
    }

    // MARK: - CalendarEventListCard

    func testCalendarEventListCardCapturesEvents() {
        let events = [previewCreated, previewPendingDeletion]
        let view = CalendarEventListCard(events: events)
        XCTAssertEqual(view.events.count, 2)
        XCTAssertEqual(view.events.first?.title, "Team Meeting")
    }

    func testCalendarEventListCardEmptyEvents() {
        let view = CalendarEventListCard(events: [])
        XCTAssertTrue(view.events.isEmpty)
    }

    func testCalendarEventListCardPreservesOrder() {
        let events = [previewPendingDeletion, previewCreated]
        let view = CalendarEventListCard(events: events)
        XCTAssertEqual(view.events[0].title, "Dentist")
        XCTAssertEqual(view.events[1].title, "Team Meeting")
    }

    // MARK: - CalendarQueryResultCard

    func testCalendarQueryResultCardCapturesSlots() {
        let slots = [
            CalendarFreeSlot(start: Date(timeIntervalSinceNow: 3600), end: Date(timeIntervalSinceNow: 7200)),
            CalendarFreeSlot(start: Date(timeIntervalSinceNow: 10800), end: Date(timeIntervalSinceNow: 14400)),
        ]
        let view = CalendarQueryResultCard(slots: slots)
        XCTAssertEqual(view.slots.count, 2)
    }

    func testCalendarQueryResultCardEmptySlots() {
        let view = CalendarQueryResultCard(slots: [])
        XCTAssertTrue(view.slots.isEmpty)
    }

    // MARK: - ConflictDetailSheet

    func testConflictDetailSheetCapturesPreview() {
        var conflictPreview = previewCreated
        conflictPreview.hasConflict = true
        let view = ConflictDetailSheet(
            preview: conflictPreview,
            onKeep: {},
            onCancel: {},
            onFindFreeSlots: { [] },
            onReschedule: { _ in }
        )
        XCTAssertEqual(view.preview.title, "Team Meeting")
        XCTAssertEqual(view.preview.hasConflict, true)
    }

    // MARK: - CreateEventSheet

    func testCreateEventSheetCapturesDraftTitle() {
        let draft = SiriPendingEvent(title: "Doctor Visit", date: Date(timeIntervalSinceNow: 86400))
        let view = CreateEventSheet(draft: draft, onConfirm: { _, _, _, _, _, _ in })
        XCTAssertEqual(view.draft.title, "Doctor Visit")
    }

    func testCreateEventSheetOnConfirmFires() throws {
        let draft = SiriPendingEvent(title: "Meeting", date: Date(timeIntervalSinceNow: 3600))
        var confirmed = false
        let view = CreateEventSheet(draft: draft, onConfirm: { _, _, _, _, _, _ in confirmed = true })
        try view.onConfirm("Meeting", Date(), Date(timeIntervalSinceNow: 3600), false, nil, nil)
        XCTAssertTrue(confirmed)
    }

    // MARK: - ModelDownloadView

    func testModelDownloadViewInstantiatesWithViewModel() {
        let vm = ModelDownloadViewModel(
            llmService: MockLLMService(),
            settings: MockAppSettings(),
            downloader: MockModelDownloader()
        )
        _ = ModelDownloadView(viewModel: vm)
        XCTAssertFalse(vm.availableModels.isEmpty)
    }

    func testModelDownloadViewReflectsIdleState() {
        let vm = ModelDownloadViewModel(
            llmService: MockLLMService(),
            settings: MockAppSettings(),
            downloader: MockModelDownloader()
        )
        XCTAssertEqual(vm.downloadState, .idle)
        XCTAssertFalse(vm.isModelLoaded)
    }
}
