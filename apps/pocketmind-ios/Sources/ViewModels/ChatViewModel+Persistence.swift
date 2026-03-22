import Foundation

@MainActor
extension ChatViewModel {

    func clearHistory() {
        llmService.cancelGeneration()
        messages = []
        if let sm = sessionManager, let sid = sessionID {
            let session = ChatSession(
                id: sid, title: sessionTitle,
                createdAt: sessionCreatedAt, updatedAt: .now, messages: []
            )
            sm.save(session)
        } else {
            history.clear()
        }
    }

    /// Immediately writes current messages to disk — call when app enters background.
    func flushPersistence() {
        if let sm = sessionManager, let sid = sessionID {
            let session = ChatSession(
                id: sid, title: sessionTitle,
                createdAt: sessionCreatedAt, updatedAt: .now, messages: messages
            )
            sm.save(session)
        } else {
            history.save(messages)
        }
    }

}
