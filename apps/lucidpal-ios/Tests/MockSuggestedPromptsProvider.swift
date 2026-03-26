import Foundation
@testable import LucidPal

@MainActor
final class MockSuggestedPromptsProvider: SuggestedPromptsProviderProtocol {
    var stubbedPrompts: [String] = [
        "What's on my calendar today?",
        "Am I free this afternoon?",
        "Add a meeting tomorrow",
        "Find a free hour today",
    ]

    func buildPrompts() -> [String] { stubbedPrompts }
}
