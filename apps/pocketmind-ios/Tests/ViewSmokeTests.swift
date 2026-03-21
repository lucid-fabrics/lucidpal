import XCTest
import SwiftUI
@testable import PocketMind

/// Smoke tests that verify View structs can be instantiated with representative data
/// without crashing, and that they capture the correct model data.
@MainActor
final class ViewSmokeTests: XCTestCase {

    // MARK: - Shared test data

    private var userMessage: ChatMessage {
        ChatMessage(role: .user, content: "Hello, what's on my calendar?")
    }

    private var assistantMessage: ChatMessage {
        ChatMessage(role: .assistant, content: "Here are your events for today.")
    }

    private var thinkingMessage: ChatMessage {
        ChatMessage(role: .assistant, content: "Answer", thinkingContent: "Let me think...", isThinking: false)
    }

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

    private var previewPendingUpdate: CalendarEventPreview {
        var preview = CalendarEventPreview(
            title: "Standup",
            start: Date(timeIntervalSinceNow: 1800),
            end: Date(timeIntervalSinceNow: 5400),
            calendarName: "Work",
            state: .pendingUpdate,
            eventIdentifier: "evt-003"
        )
        var update = PendingCalendarUpdate()
        update.title = "Daily Standup"
        preview.pendingUpdate = update
        return preview
    }

    // MARK: - MessageBubbleView

    func testMessageBubbleViewCapturesUserMessage() {
        let view = MessageBubbleView(message: userMessage)
        XCTAssertEqual(view.message.role, .user)
        XCTAssertEqual(view.message.content, "Hello, what's on my calendar?")
    }

    func testMessageBubbleViewCapturesAssistantMessage() {
        let view = MessageBubbleView(message: assistantMessage)
        XCTAssertEqual(view.message.role, .assistant)
        XCTAssertEqual(view.message.content, "Here are your events for today.")
    }

    func testMessageBubbleViewCapturesThinkingContent() {
        let view = MessageBubbleView(message: thinkingMessage)
        XCTAssertEqual(view.message.thinkingContent, "Let me think...")
        XCTAssertFalse(view.message.isThinking)
    }

    func testMessageBubbleViewCapturesCalendarPreviews() {
        var msg = assistantMessage
        msg.calendarEventPreviews = [previewCreated, previewPendingDeletion]
        let view = MessageBubbleView(message: msg)
        XCTAssertEqual(view.message.calendarEventPreviews.count, 2)
        XCTAssertEqual(view.message.calendarEventPreviews.first?.title, "Team Meeting")
    }

    // MARK: - CalendarEventCard

    func testCalendarEventCardCapturesCreatedState() {
        let view = CalendarEventCard(
            preview: previewCreated,
            onConfirm: {}, onCancel: {}, onUndo: {},
            onConfirmUpdate: {}, onCancelUpdate: {}
        )
        XCTAssertEqual(view.preview.state, .created)
        XCTAssertEqual(view.preview.title, "Team Meeting")
    }

    func testCalendarEventCardCapturesPendingDeletionState() {
        let view = CalendarEventCard(
            preview: previewPendingDeletion,
            onConfirm: {}, onCancel: {}, onUndo: {},
            onConfirmUpdate: {}, onCancelUpdate: {}
        )
        XCTAssertEqual(view.preview.state, .pendingDeletion)
        XCTAssertEqual(view.preview.title, "Dentist")
    }

    func testCalendarEventCardCapturesPendingUpdateWithDiff() {
        let view = CalendarEventCard(
            preview: previewPendingUpdate,
            onConfirm: {}, onCancel: {}, onUndo: {},
            onConfirmUpdate: {}, onCancelUpdate: {}
        )
        XCTAssertEqual(view.preview.state, .pendingUpdate)
        XCTAssertEqual(view.preview.pendingUpdate?.title, "Daily Standup")
    }

    func testCalendarEventCardCapturesDeletedState() {
        var preview = previewCreated
        preview.state = .deleted
        let view = CalendarEventCard(
            preview: preview,
            onConfirm: {}, onCancel: {}, onUndo: {},
            onConfirmUpdate: {}, onCancelUpdate: {}
        )
        XCTAssertEqual(view.preview.state, .deleted)
    }

    // MARK: - ThinkingDisclosure

    func testThinkingDisclosureStreamingHasEmptyContent() {
        var expanded = false
        let view = ThinkingDisclosure(
            content: "",
            isThinking: true,
            isExpanded: Binding(get: { expanded }, set: { expanded = $0 })
        )
        XCTAssertTrue(view.isThinking)
        XCTAssertEqual(view.content, "")
    }

    func testThinkingDisclosureWithContentIsNotThinking() {
        var expanded = true
        let view = ThinkingDisclosure(
            content: "Some reasoning",
            isThinking: false,
            isExpanded: Binding(get: { expanded }, set: { expanded = $0 })
        )
        XCTAssertFalse(view.isThinking)
        XCTAssertEqual(view.content, "Some reasoning")
    }

    // MARK: - BulkDeletionBar

    func testBulkDeletionBarCapturesCount() {
        let view = BulkDeletionBar(count: 3, onDeleteAll: {}, onKeepAll: {})
        XCTAssertEqual(view.count, 3)
    }

    func testBulkDeletionBarCountOfOne() {
        let view = BulkDeletionBar(count: 1, onDeleteAll: {}, onKeepAll: {})
        XCTAssertEqual(view.count, 1)
    }

    // MARK: - DesignConstants

    func testDesignConstantsHavePositiveValues() {
        XCTAssertGreaterThan(DesignConstants.CornerRadius.card, 0)
        XCTAssertGreaterThan(DesignConstants.CornerRadius.badge, 0)
        XCTAssertGreaterThan(DesignConstants.CornerRadius.bubble, 0)
        XCTAssertGreaterThan(DesignConstants.Padding.card, 0)
        XCTAssertGreaterThan(DesignConstants.Padding.bubbleHorizontal, 0)
        XCTAssertGreaterThan(DesignConstants.Size.dateBadgeWidth, 0)
        XCTAssertGreaterThan(DesignConstants.Size.dividerHeight, 0)
    }

    func testDesignConstantsOpacityInRange() {
        XCTAssertGreaterThan(DesignConstants.Opacity.dimmed, 0)
        XCTAssertLessThanOrEqual(DesignConstants.Opacity.dimmed, 1)
        XCTAssertGreaterThan(DesignConstants.Opacity.conflictBorder, 0)
        XCTAssertLessThanOrEqual(DesignConstants.Opacity.conflictBorder, 1)
    }

    func testBubbleCornerRadiusLargerThanCardRadius() {
        XCTAssertGreaterThan(DesignConstants.CornerRadius.bubble, DesignConstants.CornerRadius.card)
    }

    // MARK: - ToastView

    func testToastViewCapturesMessage() {
        let item = ToastItem(message: "Event created", systemImage: "checkmark.circle")
        let view = ToastView(item: item)
        XCTAssertEqual(view.item.message, "Event created")
        XCTAssertEqual(view.item.systemImage, "checkmark.circle")
    }

    func testToastItemEquality() {
        let a = ToastItem(message: "Hello", systemImage: "star")
        let b = ToastItem(message: "Hello", systemImage: "star")
        XCTAssertEqual(a, b)
    }

    func testToastItemInequalityOnMessage() {
        let a = ToastItem(message: "First", systemImage: "star")
        let b = ToastItem(message: "Second", systemImage: "star")
        XCTAssertNotEqual(a, b)
    }
}
