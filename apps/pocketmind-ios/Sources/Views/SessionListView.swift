import SwiftUI

struct SessionListView: View {
    @ObservedObject var viewModel: SessionListViewModel
    @State private var navigationPath: [ChatSessionMeta] = []
    @State private var searchText = ""
    @State private var renamingSession: ChatSessionMeta?
    @State private var renameText = ""

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if viewModel.sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("Chats")
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search chats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let session = viewModel.createSession()
                        navigationPath.append(session.meta)
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .fontWeight(.medium)
                    }
                }
            }
            .navigationDestination(for: ChatSessionMeta.self) { meta in
                ChatSessionContainer(meta: meta, listViewModel: viewModel)
            }
            .onChange(of: viewModel.siriNavigationMeta) { _, meta in
                guard let meta else { return }
                viewModel.siriNavigationMeta = nil
                navigationPath = [meta]
            }
            .sheet(item: $viewModel.pendingEventCreation) { draft in
                CreateEventSheet(draft: draft) { title, start, end, allDay, location, notes in
                    try viewModel.createCalendarEvent(
                        title: title, start: start, end: end,
                        isAllDay: allDay, location: location, notes: notes
                    )
                }
            }
            .alert("Rename Chat", isPresented: Binding(
                get: { renamingSession != nil },
                set: { if !$0 { renamingSession = nil } }
            )) {
                TextField("Chat name", text: $renameText)
                Button("Save") {
                    if let session = renamingSession, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                        viewModel.renameSession(id: session.id, title: renameText.trimmingCharacters(in: .whitespaces))
                    }
                    renamingSession = nil
                }
                Button("Cancel", role: .cancel) { renamingSession = nil }
            }
        }
    }

    // MARK: - Session List

    private var sessionList: some View {
        List {
            ForEach(groupedSections, id: \.title) { section in
                Section(header: Text(section.title).font(.footnote).fontWeight(.semibold)) {
                    ForEach(section.sessions) { meta in
                        Button {
                            navigationPath.append(meta)
                        } label: {
                            SessionRowView(meta: meta, searchText: searchText)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                renameText = meta.title
                                renamingSession = meta
                            } label: {
                                Label("Rename", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                viewModel.deleteSession(id: meta.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteSession(id: section.sessions[index].id)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Grouping

    private var filteredSessions: [ChatSessionMeta] {
        guard !searchText.isEmpty else { return viewModel.sessions }
        return viewModel.sessions.filter {
            $0.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    private struct SessionSection {
        let title: String
        let sessions: [ChatSessionMeta]
    }

    private var groupedSections: [SessionSection] {
        let cal = Calendar.current
        let now = Date.now

        var today: [ChatSessionMeta] = []
        var yesterday: [ChatSessionMeta] = []
        var thisWeek: [ChatSessionMeta] = []
        var earlier: [ChatSessionMeta] = []

        for meta in filteredSessions {
            if cal.isDateInToday(meta.updatedAt) {
                today.append(meta)
            } else if cal.isDateInYesterday(meta.updatedAt) {
                yesterday.append(meta)
            } else if let weekAgo = cal.date(byAdding: .day, value: -7, to: now),
                      meta.updatedAt >= weekAgo {
                thisWeek.append(meta)
            } else {
                earlier.append(meta)
            }
        }

        return [
            SessionSection(title: "Today", sessions: today),
            SessionSection(title: "Yesterday", sessions: yesterday),
            SessionSection(title: "This Week", sessions: thisWeek),
            SessionSection(title: "Earlier", sessions: earlier),
        ].filter { !$0.sessions.isEmpty }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Color.accentColor.opacity(0.5))
                .padding(.bottom, 4)
            Text("No chats yet")
                .font(.title3.weight(.semibold))
            Text("Tap the pencil icon to start a conversation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Session Row

private struct SessionRowView: View {
    let meta: ChatSessionMeta
    var searchText: String = ""

    private var highlightedTitle: AttributedString {
        var attributed = AttributedString(meta.title)
        guard !searchText.isEmpty,
              let range = attributed.range(of: searchText, options: .caseInsensitive) else {
            return attributed
        }
        attributed[range].foregroundColor = .accentColor
        attributed[range].font = .body.bold()
        return attributed
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(highlightedTitle)
                        .font(.body.weight(.semibold))
                        .lineLimit(1)
                    Spacer()
                    Text(smartTimestamp)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let preview = meta.lastMessagePreview, !preview.isEmpty {
                    Text(preview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text("No messages yet")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .italic()
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 42, height: 42)
            Image(systemName: "sparkles")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.accentColor)
        }
    }

    private var smartTimestamp: String {
        let cal = Calendar.current
        let date = meta.updatedAt
        if cal.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if cal.isDateInYesterday(date) {
            return "Yesterday"
        } else if let weekAgo = cal.date(byAdding: .day, value: -7, to: .now), date >= weekAgo {
            return date.formatted(.dateTime.weekday(.wide))
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Session Container

/// Owns a per-session ChatViewModel and handles background persistence flushing.
struct ChatSessionContainer: View {
    let meta: ChatSessionMeta
    let listViewModel: SessionListViewModel

    @StateObject private var chatViewModel: ChatViewModel
    @Environment(\.scenePhase) private var scenePhase

    init(meta: ChatSessionMeta, listViewModel: SessionListViewModel) {
        self.meta = meta
        self.listViewModel = listViewModel
        let session = listViewModel.loadFullSession(meta: meta)
        // Consume any pending Siri query for this session — dict avoids timing issues with onChange.
        let query = listViewModel.pendingQueryBySessionID[meta.id]
        listViewModel.pendingQueryBySessionID.removeValue(forKey: meta.id)
        _chatViewModel = StateObject(
            wrappedValue: listViewModel.makeChatViewModel(for: session, initialQuery: query)
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
