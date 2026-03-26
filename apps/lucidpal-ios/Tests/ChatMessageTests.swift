@testable import LucidPal
import XCTest

@MainActor
final class ChatMessageTests: XCTestCase {

    // MARK: - isUser

    func testIsUserTrueForUserRole() {
        XCTAssertTrue(ChatMessage(role: .user, content: "hi").isUser)
    }

    func testIsUserFalseForAssistantRole() {
        XCTAssertFalse(ChatMessage(role: .assistant, content: "hi").isUser)
    }

    func testIsUserFalseForSystemRole() {
        XCTAssertFalse(ChatMessage(role: .system, content: "hi").isUser)
    }

    // MARK: - Default values

    func testDefaultValuesAreCorrect() {
        let msg = ChatMessage(role: .user, content: "hello")
        XCTAssertNil(msg.thinkingContent)
        XCTAssertFalse(msg.isThinking)
        XCTAssertTrue(msg.calendarEventPreviews.isEmpty)
    }

    func testThinkingContentIsPreserved() {
        let msg = ChatMessage(role: .assistant, content: "answer", thinkingContent: "reasoning", isThinking: true)
        XCTAssertEqual(msg.thinkingContent, "reasoning")
        XCTAssertTrue(msg.isThinking)
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let msg = ChatMessage(role: .user, content: "test content")
        let decoded = try JSONDecoder().decode(ChatMessage.self, from: JSONEncoder().encode(msg))
        XCTAssertEqual(decoded.id, msg.id)
        XCTAssertEqual(decoded.role, .user)
        XCTAssertEqual(decoded.content, "test content")
    }

    func testMessageRoleRawValues() {
        XCTAssertEqual(MessageRole.user.rawValue, "user")
        XCTAssertEqual(MessageRole.assistant.rawValue, "assistant")
        XCTAssertEqual(MessageRole.system.rawValue, "system")
    }

    func testMessageRoleDecodable() throws {
        let json = #"{"role":"assistant"}"#
        struct Wrapper: Decodable { let role: MessageRole }
        let w = try JSONDecoder().decode(Wrapper.self, from: try XCTUnwrap(json.data(using: .utf8)))
        XCTAssertEqual(w.role, .assistant)
    }

    // MARK: - CalendarEventPreview Codable

    func testCalendarEventPreviewCodableRoundTrip() throws {
        let preview = CalendarEventPreview(
            title: "Dentist",
            start: Date(timeIntervalSince1970: 1_000_000),
            end: Date(timeIntervalSince1970: 1_003_600),
            calendarName: "Work",
            state: .pendingDeletion,
            eventIdentifier: "evt-1",
            reminderMinutes: 15,
            isAllDay: false
        )
        let decoded = try JSONDecoder().decode(CalendarEventPreview.self, from: JSONEncoder().encode(preview))
        XCTAssertEqual(decoded.id, preview.id)
        XCTAssertEqual(decoded.title, "Dentist")
        XCTAssertEqual(decoded.state, .pendingDeletion)
        XCTAssertEqual(decoded.eventIdentifier, "evt-1")
        XCTAssertEqual(decoded.reminderMinutes, 15)
        XCTAssertFalse(decoded.isAllDay)
    }

    func testPreviewStateAllCasesHaveRawValues() {
        let states: [CalendarEventPreview.PreviewState] = [
            .created, .updated, .rescheduled, .pendingDeletion, .deleted,
            .deletionCancelled, .restored, .pendingUpdate, .updateCancelled
        ]
        XCTAssertEqual(states.count, 9)
        for state in states {
            XCTAssertFalse(state.rawValue.isEmpty)
        }
    }

    // MARK: - PendingCalendarUpdate Codable

    func testPendingCalendarUpdateCodableRoundTrip() throws {
        var update = PendingCalendarUpdate()
        update.title = "New Title"
        update.reminderMinutes = 30
        let decoded = try JSONDecoder().decode(PendingCalendarUpdate.self, from: JSONEncoder().encode(update))
        XCTAssertEqual(decoded.title, "New Title")
        XCTAssertEqual(decoded.reminderMinutes, 30)
        XCTAssertNil(decoded.start)
        XCTAssertNil(decoded.end)
    }

    // MARK: - displayContent

    func testDisplayContentStripsCompleteActionBlock() {
        let msg = ChatMessage(role: .assistant, content: "[CALENDAR_ACTION:{\"action\":\"create\"}]\nAdded.")
        XCTAssertEqual(msg.displayContent, "Added.")
    }

    func testDisplayContentStripsPartialActionBlock() {
        let msg = ChatMessage(role: .assistant, content: "Sure [CALENDAR_ACTION:{\"action\":")
        XCTAssertEqual(msg.displayContent, "Sure")
    }

    func testDisplayContentPassesThroughPlainText() {
        let msg = ChatMessage(role: .assistant, content: "Hello there!")
        XCTAssertEqual(msg.displayContent, "Hello there!")
    }

    // MARK: - isStreamingAction

    func testIsStreamingActionTrueWhileStreaming() {
        let msg = ChatMessage(role: .assistant, content: "Here [CALENDAR_ACTION:{\"action\":\"create\"}]")
        XCTAssertTrue(msg.isStreamingAction)
    }

    func testIsStreamingActionFalseWhenPreviewsPopulated() {
        var msg = ChatMessage(role: .assistant, content: "[CALENDAR_ACTION:{\"action\":\"create\"}]")
        let preview = CalendarEventPreview(title: "X", start: .now, end: .now, calendarName: nil, state: .created)
        msg.calendarEventPreviews = [preview]
        XCTAssertFalse(msg.isStreamingAction)
    }

    func testIsStreamingActionFalseForNormalContent() {
        let msg = ChatMessage(role: .assistant, content: "Hello, no action here")
        XCTAssertFalse(msg.isStreamingAction)
    }

    func testPendingCalendarUpdateEquality() {
        var a = PendingCalendarUpdate()
        a.title = "X"
        var b = PendingCalendarUpdate()
        b.title = "X"
        XCTAssertEqual(a, b)
        b.title = "Y"
        XCTAssertNotEqual(a, b)
    }
}
