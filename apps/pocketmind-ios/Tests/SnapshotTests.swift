@testable import PocketMind
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class SnapshotTests: XCTestCase {

    // MARK: - Helpers

    private func makeViewModel(loaded: Bool = true, messages: [ChatMessage] = []) -> ChatViewModel {
        let llm = MockLLMService()
        llm.isLoaded = loaded
        let vm = ChatViewModel(
            llmService: llm,
            calendarService: MockCalendarService(),
            settings: MockAppSettings(),
            systemPromptBuilder: MockSystemPromptBuilder(),
            suggestedPromptsProvider: MockSuggestedPromptsProvider(),
            speechService: MockSpeechService(),
            hapticService: MockHapticService(),
            historyManager: MockChatHistoryManager()
        )
        vm.messages = messages
        return vm
    }

    // Snapshots are written to /tmp/pocketmind-snapshots/__Snapshots__/SnapshotTests/
    private static let snapshotFile: StaticString = "/tmp/pocketmind-snapshots/SnapshotTests.swift"

    private func snapshot<V: View>(_ view: V, named name: String? = nil, testName: String = #function, line: UInt = #line) {
        let vc = UIHostingController(rootView: view)
        assertSnapshot(
            of: vc,
            as: .image(on: .iPhone13Pro),
            named: name,
            record: true,
            file: Self.snapshotFile,
            testName: testName,
            line: line
        )
    }

    // MARK: - MessageBubbleView — text bubbles

    func testUserBubble() {
        let msg = ChatMessage(role: .user, content: "Can you explain how machine learning works?")
        snapshot(
            MessageBubbleView(message: msg)
                .frame(width: 390)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
        )
    }

    func testAssistantBubble() {
        // swiftlint:disable:next line_length
        let msg = ChatMessage(role: .assistant, content: "Machine learning is a subset of AI where models learn **patterns from data** rather than following explicit rules.")
        snapshot(
            MessageBubbleView(message: msg)
                .frame(width: 390)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
        )
    }

    func testStreamingSkeleton() {
        let msg = ChatMessage(role: .assistant, content: "")
        snapshot(
            MessageBubbleView(message: msg)
                .frame(width: 390)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
        )
    }

    // MARK: - MessageBubbleView — thinking states

    func testThinkingBubble() {
        // swiftlint:disable line_length
        var msg = ChatMessage(role: .assistant, content: "The Eiffel Tower is **330 meters** tall including its antenna, making it the tallest structure in Paris.")
        msg.thinkingContent = "The user is asking about the Eiffel Tower height. I should include the full height with the antenna as that is the commonly cited figure."
        // swiftlint:enable line_length
        snapshot(
            MessageBubbleView(message: msg)
                .frame(width: 390)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
        )
    }

    func testThinkingInProgress() {
        var msg = ChatMessage(role: .assistant, content: "")
        msg.isThinking = true
        snapshot(
            MessageBubbleView(message: msg)
                .frame(width: 390)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
        )
    }

    // MARK: - MessageBubbleView — calendar cards

    /// Pending deletion card — shows Keep / Delete actions.
    func testCalendarEventCard() {
        let preview = CalendarEventPreview(
            title: "Dentist Appointment",
            start: Date(timeIntervalSince1970: 1_750_000_000),
            end: Date(timeIntervalSince1970: 1_750_003_600),
            calendarName: "Personal",
            state: .pendingDeletion,
            eventIdentifier: "evt-1"
        )
        var msg = ChatMessage(role: .assistant, content: "I found your dentist appointment. Delete it?")
        msg.calendarEventPreviews = [preview]
        snapshot(
            MessageBubbleView(message: msg)
                .frame(width: 390)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
        )
    }

    /// Created event card — shown after a successful event creation.
    func testCreatedEventCard() {
        let preview = CalendarEventPreview(
            title: "Team Lunch",
            start: Date(timeIntervalSince1970: 1_750_050_000),
            end: Date(timeIntervalSince1970: 1_750_053_600),
            calendarName: "Work",
            state: .created,
            eventIdentifier: "evt-2"
        )
        var msg = ChatMessage(role: .assistant, content: "Done! **Team Lunch** has been added to your Work calendar.")
        msg.calendarEventPreviews = [preview]
        snapshot(
            MessageBubbleView(message: msg)
                .frame(width: 390)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
        )
    }

    /// Grouped listed events card — shown when the user asks what's on their calendar.
    func testCalendarEventListCard() {
        let today = Calendar.current.startOfDay(for: Date())
        // swiftlint:disable line_length
        let listed: [CalendarEventPreview] = [
            CalendarEventPreview(title: "Standup", start: today.addingTimeInterval(9 * 3600), end: today.addingTimeInterval(9.5 * 3600), calendarName: "Work", state: .listed),
            CalendarEventPreview(title: "Design Review", start: today.addingTimeInterval(14 * 3600), end: today.addingTimeInterval(15 * 3600), calendarName: "Work", state: .listed),
            CalendarEventPreview(title: "Gym", start: today.addingTimeInterval(17 * 3600), end: today.addingTimeInterval(18 * 3600), calendarName: "Personal", state: .listed),
        ]
        // swiftlint:enable line_length
        var msg = ChatMessage(role: .assistant, content: "You have 3 events today.")
        msg.calendarEventPreviews = listed
        snapshot(
            MessageBubbleView(message: msg)
                .frame(width: 390)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
        )
    }

    // MARK: - ChatView — empty states

    func testChatEmptyNoModel() {
        let vm = makeViewModel(loaded: false)
        snapshot(NavigationStack { ChatView(viewModel: vm) })
    }

    func testChatEmptyModelLoaded() {
        let vm = makeViewModel(loaded: true)
        snapshot(NavigationStack { ChatView(viewModel: vm) })
    }

    // MARK: - ChatView — conversations

    /// User asks what's on today — assistant replies with a grouped calendar card.
    func testChatShortConversation() {
        let today = Calendar.current.startOfDay(for: Date())
        // swiftlint:disable line_length
        let listed: [CalendarEventPreview] = [
            CalendarEventPreview(title: "Standup", start: today.addingTimeInterval(9 * 3600), end: today.addingTimeInterval(9.5 * 3600), calendarName: "Work", state: .listed),
            CalendarEventPreview(title: "Design Review", start: today.addingTimeInterval(14 * 3600), end: today.addingTimeInterval(15 * 3600), calendarName: "Work", state: .listed),
            CalendarEventPreview(title: "Gym", start: today.addingTimeInterval(17 * 3600), end: today.addingTimeInterval(18 * 3600), calendarName: "Personal", state: .listed),
        ]
        // swiftlint:enable line_length
        var assistantMsg = ChatMessage(role: .assistant, content: "You have 3 events today.")
        assistantMsg.calendarEventPreviews = listed
        let vm = makeViewModel(loaded: true, messages: [
            ChatMessage(role: .user, content: "What's on my schedule today?"),
            assistantMsg,
        ])
        snapshot(NavigationStack { ChatView(viewModel: vm) })
    }

    /// User creates an event — assistant replies with confirmation text + created event card.
    func testChatWithTypedInput() {
        let created = CalendarEventPreview(
            title: "Dentist Appointment",
            start: Date(timeIntervalSince1970: 1_750_050_000),
            end: Date(timeIntervalSince1970: 1_750_053_600),
            calendarName: "Personal",
            state: .created,
            eventIdentifier: "evt-3"
        )
        var assistantMsg = ChatMessage(role: .assistant, content: "Done! I've added **Dentist Appointment** on Friday at 10:00am to your Personal calendar.")
        assistantMsg.calendarEventPreviews = [created]
        let vm = makeViewModel(loaded: true, messages: [
            ChatMessage(role: .user, content: "Add a dentist appointment Friday at 10am"),
            assistantMsg,
        ])
        vm.inputText = "Find a free slot tomorrow afternoon"
        snapshot(NavigationStack { ChatView(viewModel: vm) })
    }

    /// Thinking reply — collapsed "Thought for a moment" header + text answer.
    func testChatWithThinkingReply() {
        var thinkingMsg = ChatMessage(role: .assistant, content: "You have a free slot from 2pm to 4pm tomorrow.")
        thinkingMsg.thinkingContent = "Checking calendar for tomorrow... scanning 10am–6pm window... found a 2-hour gap at 2pm."
        let vm = makeViewModel(loaded: true, messages: [
            ChatMessage(role: .user, content: "Find me a free 2-hour slot tomorrow"),
            thinkingMsg,
        ])
        snapshot(NavigationStack { ChatView(viewModel: vm) })
    }

    /// Model is generating — skeleton bubble + red stop button.
    func testChatGenerating() {
        let llm = MockLLMService()
        llm.isLoaded = true
        llm.isGenerating = true
        let vm = ChatViewModel(
            llmService: llm,
            calendarService: MockCalendarService(),
            settings: MockAppSettings(),
            systemPromptBuilder: MockSystemPromptBuilder(),
            suggestedPromptsProvider: MockSuggestedPromptsProvider(),
            speechService: MockSpeechService(),
            hapticService: MockHapticService(),
            historyManager: MockChatHistoryManager()
        )
        vm.messages = [
            ChatMessage(role: .user, content: "Summarize the history of the internet."),
            ChatMessage(role: .assistant, content: ""),   // streaming skeleton
        ]
        snapshot(NavigationStack { ChatView(viewModel: vm) })
    }
}
