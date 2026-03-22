import SwiftUI
// UIKit is used solely for UIPasteboard clipboard access — no UI components imported.
import UIKit

struct MessageBubbleView: View {
    let message: ChatMessage
    var userPrompt: String? = nil
    var onReply: ((ChatMessage) -> Void)? = nil
    var onConfirmDeletion: ((UUID) -> Void)? = nil
    var onCancelDeletion: ((UUID) -> Void)? = nil
    var onUndoDeletion: ((UUID) -> Void)? = nil
    var onConfirmUpdate: ((UUID) -> Void)? = nil
    var onCancelUpdate: ((UUID) -> Void)? = nil
    var onConfirmAllDeletions: (() -> Void)? = nil
    var onCancelAllDeletions: (() -> Void)? = nil
    var onDeleteMessage: ((UUID) -> Void)? = nil
    var onKeepConflict: ((UUID) -> Void)? = nil
    var onCancelConflict: ((UUID) async -> Void)? = nil
    var onFindFreeSlots: ((UUID) async -> [CalendarFreeSlot])? = nil
    var onRescheduleToSlot: ((UUID, CalendarFreeSlot) async -> Void)? = nil
    @State private var thinkingExpanded = false
    @State private var showTimestamp = false
    @State private var swipeOffset: CGFloat = 0
    @State private var replyTriggered = false

    private let replyThreshold: CGFloat = 60
    /// Max swipe travel expressed as a multiple of replyThreshold (30% overshoot).
    private let swipeExtentFactor: CGFloat = 1.3
    /// Resistance damping applied to raw drag offset so the gesture feels spring-like.
    private let swipeResistanceFactor: CGFloat = 0.55
    /// Fraction of the damped threshold at which the reply action fires.
    private let swipeTriggerRatio: CGFloat = 0.9

    private var pendingDeletionCount: Int {
        message.calendarEventPreviews.filter { $0.state == .pendingDeletion }.count
    }

    var body: some View {
        ZStack(alignment: .leading) {
            Image(systemName: "arrowshape.turn.up.left.fill")
                .font(.body)
                .foregroundStyle(Color.accentColor)
                .opacity(Double(min(swipeOffset, replyThreshold)) / replyThreshold)
                .scaleEffect(min(swipeOffset / replyThreshold, 1.0))
                .padding(.leading, 20)

            HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: DesignConstants.Size.messageSpacer) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                // Thinking disclosure (assistant only)
                if !message.isUser, let thinking = message.thinkingContent {
                    ThinkingDisclosure(content: thinking, isThinking: message.isThinking, isExpanded: $thinkingExpanded)
                } else if !message.isUser && message.isThinking {
                    // Think tag detected but no content yet — show pill immediately
                    ThinkingDisclosure(content: "", isThinking: true, isExpanded: $thinkingExpanded)
                }

                // Main bubble — action block stripped; shown as pill below
                let bubbleText = message.displayContent
                if !bubbleText.isEmpty {
                    bubbleTextView(bubbleText, isUser: message.isUser)
                        .padding(.horizontal, DesignConstants.Padding.bubbleHorizontal)
                        .padding(.vertical, DesignConstants.Padding.bubbleVertical)
                        .background(message.isUser ? Color.accentColor : Color(.systemBackground))
                        .foregroundStyle(message.isUser ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.bubble, style: .continuous))
                        .overlay {
                            if !message.isUser {
                                RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.bubble, style: .continuous)
                                    .strokeBorder(Color(.systemGray4), lineWidth: 1)
                            }
                        }
                        .shadow(color: .black.opacity(message.isUser ? 0 : 0.06), radius: 4, x: 0, y: 2)
                        .contextMenu {
                            if !message.content.isEmpty {
                                Button {
                                    UIPasteboard.general.string = message.displayContent
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                                ShareLink(item: message.displayContent) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                Divider()
                                Button(role: .destructive) {
                                    onDeleteMessage?(message.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                } else if !message.isUser && !message.isStreamingAction && message.calendarEventPreviews.isEmpty {
                    GeneratingStatusView(userPrompt: userPrompt)
                }

                // Animated pill while calendar action block is streaming
                if message.isStreamingAction {
                    CalendarActionPill()
                }

                // Animated pill while web search is executing
                if message.isStreamingWebSearch {
                    WebSearchingPill()
                }

                // Static pill after web search result is ready
                if message.isWebSearchResult {
                    WebSearchPill()
                }

                // Free slot query result
                if !message.calendarFreeSlots.isEmpty {
                    CalendarQueryResultCard(slots: message.calendarFreeSlots)
                }

                // Listed events → grouped calendar card
                let listedEvents = message.calendarEventPreviews.filter { $0.state == .listed }
                if !listedEvents.isEmpty {
                    CalendarEventListCard(events: listedEvents)
                }

                // All other calendar event cards (created, updated, pending deletion, etc.)
                ForEach(message.calendarEventPreviews.filter { $0.state != .listed }, id: \.id) { preview in
                    CalendarEventCard(
                        preview: preview,
                        onConfirm:        { onConfirmDeletion?(preview.id) },
                        onCancel:         { onCancelDeletion?(preview.id) },
                        onUndo:           { onUndoDeletion?(preview.id) },
                        onConfirmUpdate:  { onConfirmUpdate?(preview.id) },
                        onCancelUpdate:   { onCancelUpdate?(preview.id) },
                        onKeepConflict:   { onKeepConflict?(preview.id) },
                        onCancelConflict: { await onCancelConflict?(preview.id) },
                        onFindFreeSlots:  { await onFindFreeSlots?(preview.id) ?? [] },
                        onRescheduleToSlot: { slot in await onRescheduleToSlot?(preview.id, slot) }
                    )
                }

                // Bulk action bar when ≥2 pending deletions
                if pendingDeletionCount >= 2 {
                    BulkDeletionBar(
                        count: pendingDeletionCount,
                        onDeleteAll: { onConfirmAllDeletions?() },
                        onKeepAll:   { onCancelAllDeletions?() }
                    )
                }

                if showTimestamp {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignConstants.Padding.timestamp)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showTimestamp.toggle()
                }
            }

            if !message.isUser { Spacer(minLength: DesignConstants.Size.messageSpacer) }
            } // HStack
            .offset(x: swipeOffset)
        } // ZStack
        .padding(.horizontal, DesignConstants.Padding.messageHorizontal)
        .gesture(
            DragGesture(minimumDistance: 15, coordinateSpace: .local)
                .onChanged { value in
                    let dx = value.translation.width
                    let dy = abs(value.translation.height)
                    guard dx > 0, dx > dy else { swipeOffset = 0; return }
                    swipeOffset = min(dx, replyThreshold * swipeExtentFactor) * swipeResistanceFactor
                    if swipeOffset >= replyThreshold * swipeResistanceFactor * swipeTriggerRatio && !replyTriggered {
                        replyTriggered = true
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }
                }
                .onEnded { _ in
                    if replyTriggered { onReply?(message) }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { swipeOffset = 0 }
                    replyTriggered = false
                }
        )
    }
}

// MARK: - Markdown bubble text


/// Renders message text with inline markdown (bold, italic, code, links).
/// Converts leading `- ` list markers to `•` before parsing.
/// Falls back to plain text if AttributedString parsing fails.
@ViewBuilder
private func bubbleTextView(_ text: String, isUser: Bool) -> some View {
    let processed = text
        .components(separatedBy: "\n")
        .map { line -> String in
            if line.hasPrefix("* ")  { return "• " + line.dropFirst(2) }
            if line.hasPrefix("- ")  { return "• " + line.dropFirst(2) }
            return line
        }
        .joined(separator: "\n")
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    if let attributed = try? AttributedString(markdown: processed, options: options) { // safe: returns nil, falls back to plain text
        Text(attributed)
    } else {
        Text(processed)
    }
}

// MARK: - Generating status view

private struct GeneratingStatusView: View {
    var userPrompt: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dotOpacity: Double = 1
    @State private var phaseIndex: Int = 0

    // MARK: - Intent detection

    private enum Intent {
        case calendar, webSearch, generic
    }

    private var intent: Intent {
        guard let prompt = userPrompt?.lowercased() else { return .generic }
        let calendarKeywords = ["meet", "event", "schedule", "calendar", "appointment",
                                "book", "reschedule", "cancel", "free time", "available",
                                "remind", "tomorrow", "today", "next week", "this week",
                                "morning", "afternoon", "evening", "slot"]
        let searchKeywords  = ["weather", "news", "search", "latest", "current",
                                "who is", "what is", "how to", "price", "score",
                                "define", "translate", "find", "look up"]
        if calendarKeywords.contains(where: { prompt.contains($0) }) { return .calendar }
        if searchKeywords.contains(where:  { prompt.contains($0) }) { return .webSearch }
        return .generic
    }

    private var phrases: [String] {
        switch intent {
        case .calendar:
            return [
                "Checking your schedule",
                "Looking at your calendar",
                "Scanning your events",
                "Finding available slots",
                "Reviewing your day",
                "Organizing your time",
                "Almost there",
            ]
        case .webSearch:
            return [
                "Searching the web",
                "Looking that up",
                "Fetching results",
                "Reading sources",
                "Putting it together",
                "Almost there",
            ]
        case .generic:
            return [
                "Thinking",
                "Reading your message",
                "Processing",
                "Working on it",
                "Reasoning through this",
                "Putting it together",
                "Drafting a response",
                "One moment",
                "Almost there",
            ]
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 7, height: 7)
                .opacity(dotOpacity)
                .animation(
                    reduceMotion ? .default : .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                    value: dotOpacity
                )

            Text(phrases[phaseIndex % phrases.count])
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.4), value: phaseIndex)
        }
        .padding(.horizontal, DesignConstants.Padding.bubbleHorizontal)
        .padding(.vertical, DesignConstants.Padding.bubbleVertical)
        .onAppear { if !reduceMotion { dotOpacity = 0.2 } }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4.5))
                withAnimation(.easeInOut(duration: 0.4)) {
                    phaseIndex += 1
                }
            }
        }
    }
}
