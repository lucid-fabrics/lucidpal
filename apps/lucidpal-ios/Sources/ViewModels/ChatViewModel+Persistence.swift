import Foundation

@MainActor
extension ChatViewModel {

    // MARK: - Session load cleanup

    /// Clears in-flight flags persisted when the app was killed mid-generation.
    static func sanitizeStaleState(_ messages: inout [ChatMessage]) {
        for i in messages.indices where messages[i].role == .assistant {
            // Clear stuck thinking flag
            messages[i].isThinking = false

            // Web search tag present but synthesis never ran → mark interrupted
            if messages[i].isStreamingWebSearch {
                messages[i].content = "*(Search was interrupted.)*"
                messages[i].isWebSearchResult = true
            }

            // Calendar action tag present but never executed → strip the raw block
            if messages[i].isStreamingAction {
                let stripped = messages[i].content
                    .components(separatedBy: "\n")
                    .filter { !$0.contains("[CALENDAR_ACTION:") }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                messages[i].content = stripped.isEmpty ? "*(Action was interrupted.)*" : stripped
            }
        }

        // Remove dangling empty assistant messages (killed before any token was written)
        messages.removeAll {
            $0.role == .assistant
            && $0.content.isEmpty
            && $0.calendarEventPreviews.isEmpty
            && $0.calendarFreeSlots.isEmpty
        }
    }

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
