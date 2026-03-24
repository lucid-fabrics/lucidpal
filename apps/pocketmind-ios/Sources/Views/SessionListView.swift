import SwiftUI

struct SessionListView: View {
    @ObservedObject var viewModel: SessionListViewModel
    @State private var navigationPath: [ChatSessionMeta] = []
    @State private var searchText = ""
    @State private var renamingSession: ChatSessionMeta?
    @State private var renameText = ""
    @State private var pendingVoiceSessionID: UUID?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                heroSection
                if !viewModel.sessions.isEmpty {
                    sessionSections
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search chats")
            .navigationDestination(for: ChatSessionMeta.self) { meta in
                ChatSessionContainer(
                    meta: meta,
                    listViewModel: viewModel,
                    startWithVoice: meta.id == pendingVoiceSessionID
                )
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

    // MARK: - Hero

    private var heroSection: some View {
        Section {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                heroContent(now: context.date)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    private func heroContent(now: Date) -> some View {
        let event = viewModel.nextUpcomingEvent()
        let count = viewModel.todayEventCount()
        return VStack(spacing: 0) {
            heroHeader(now: now, count: count)
            heroNextEventCard(event: event, now: now)
            heroActions(event: event, now: now)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.06), Color.clear],
                startPoint: .top, endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func heroHeader(now: Date, count: Int) -> some View {
        VStack(spacing: 4) {
            Text(now, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Group {
                if count == 0 {
                    Text("Free today")
                } else {
                    Text("\(count) event\(count == 1 ? "" : "s") today")
                }
            }
            .font(.title3.weight(.bold))
        }
        .padding(.top, 28)
    }

    @ViewBuilder
    private func heroNextEventCard(event: CalendarEventInfo?, now: Date) -> some View {
        if let event, let title = event.title, !title.isEmpty {
            NextEventCard(event: event, title: title, now: now) {
                let session = viewModel.createSession()
                pendingVoiceSessionID = nil
                navigationPath.append(session.meta)
            }
            .padding(.top, 16)
            .padding(.horizontal, 16)
        }
    }

    private func heroActions(event: CalendarEventInfo?, now: Date) -> some View {
        VStack(spacing: 0) {
            PulsingMicButton {
                let session = viewModel.createSession()
                pendingVoiceSessionID = session.meta.id
                navigationPath.append(session.meta)
            }
            .padding(.top, event != nil ? 24 : 32)

            Text(contextualHint(event: event, now: now))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 10)

            Button {
                let session = viewModel.createSession()
                pendingVoiceSessionID = nil
                navigationPath.append(session.meta)
            } label: {
                Label("New text chat", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    private func contextualHint(event: CalendarEventInfo?, now: Date) -> String {
        guard let event, let title = event.title, !title.isEmpty else {
            return "Ask about your schedule, add events, or find free time"
        }
        let mins = Int(event.startDate.timeIntervalSince(now) / 60)
        let short = title.count > ChatConstants.eventTitlePreviewLength + 2 ? String(title.prefix(ChatConstants.eventTitlePreviewLength)) + "…" : title
        if mins < ChatConstants.eventStartingNowMinutes { return "\"\(short)\" is starting now" }
        if mins < ChatConstants.minutesPerHour { return "Ask about \"\(short)\"" }
        return "Tap the mic to ask about your day"
    }

    // MARK: - Session Sections

    @ViewBuilder
    private var sessionSections: some View {
        ForEach(viewModel.groupedSessions(searchText: searchText), id: \.title) { section in
            Section(header: Text(section.title).font(.footnote).fontWeight(.semibold)) {
                ForEach(section.sessions) { meta in
                    Button {
                        pendingVoiceSessionID = nil
                        navigationPath.append(meta)
                    } label: {
                        SessionRowView(meta: meta, searchText: searchText)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading) {
                        Button {
                            renameText = meta.title
                            renamingSession = meta
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }
                        .tint(.accentColor)
                    }
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

}
