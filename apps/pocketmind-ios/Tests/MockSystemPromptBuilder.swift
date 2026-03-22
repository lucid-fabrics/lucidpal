import Foundation
@testable import PocketMind

@MainActor
final class MockSystemPromptBuilder: SystemPromptBuilderProtocol {
    var stubbedPrompt = "You are a test assistant."
    var executeCalendarActionsResult: (content: String, previews: [CalendarEventPreview], freeSlots: [CalendarFreeSlot]) = ("", [], [])
    var executeCalendarActionsCalled = false

    func buildSystemPrompt() async -> String { stubbedPrompt }

    func executeCalendarActions(in text: String) async -> (content: String, previews: [CalendarEventPreview], freeSlots: [CalendarFreeSlot]) {
        executeCalendarActionsCalled = true
        let result = executeCalendarActionsResult
        return (result.content.isEmpty ? text : result.content, result.previews, result.freeSlots)
    }

    func extractWebSearchQuery(from text: String) -> (query: String, maxResults: Int)? { nil }
}
