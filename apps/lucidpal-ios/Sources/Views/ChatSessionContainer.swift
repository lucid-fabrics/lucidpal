import SwiftUI

// MARK: - Session Container

/// Owns a per-session ChatViewModel and handles background persistence flushing.
struct ChatSessionContainer: View {
    let meta: ChatSessionMeta
    let listViewModel: SessionListViewModel

    @StateObject private var chatViewModel: ChatViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(meta: ChatSessionMeta, listViewModel: SessionListViewModel, startWithVoice: Bool = false) {
        self.meta = meta
        self.listViewModel = listViewModel
        let session = listViewModel.loadFullSession(meta: meta)
        // Consume any pending Siri query for this session — dict avoids timing issues with onChange.
        let query = listViewModel.pendingQueryBySessionID[meta.id]
        listViewModel.pendingQueryBySessionID.removeValue(forKey: meta.id)
        _chatViewModel = StateObject(
            wrappedValue: listViewModel.makeChatViewModel(for: session, initialQuery: query, startWithVoice: startWithVoice)
        )
    }

    var body: some View {
        ChatView(viewModel: chatViewModel)
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    chatViewModel.flushPersistence()
                } else if phase == .active {
                    chatViewModel.refreshStalePreviews()
                }
            }
    }
}
