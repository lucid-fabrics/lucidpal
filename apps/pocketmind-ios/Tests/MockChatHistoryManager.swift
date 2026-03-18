import Foundation
@testable import PocketMind

@MainActor
final class MockChatHistoryManager: ChatHistoryManagerProtocol {
    var storedMessages: [ChatMessage] = []
    var saveCalled = false
    var clearCalled = false

    func load() -> [ChatMessage] {
        storedMessages
    }

    @discardableResult
    func save(_ messages: [ChatMessage]) -> Task<Void, Never> {
        saveCalled = true
        storedMessages = messages
        return Task {}
    }

    func clear() {
        clearCalled = true
        storedMessages = []
    }
}
