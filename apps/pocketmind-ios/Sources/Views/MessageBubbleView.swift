import OSLog
import SwiftUI
// UIKit is used solely for UIPasteboard clipboard access — no UI components imported.
import UIKit

private let messageBubbleLogger = Logger(subsystem: "app.pocketmind", category: "MessageBubble")

struct MessageBubbleView: View {
    let message: ChatMessage
    var userPrompt: String? = nil
    var isStreaming: Bool = false
    var isFirstInGroup: Bool = true
    var isLastInGroup: Bool = true
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
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let replyThreshold: CGFloat = 60
    /// Max swipe travel expressed as a multiple of replyThreshold (30% overshoot).
    private let swipeExtentFactor: CGFloat = 1.3
    /// Resistance damping applied to raw drag offset so the gesture feels spring-like.
    private let swipeResistanceFactor: CGFloat = 0.55
    /// Fraction of the damped threshold at which the reply action fires.
    private let swipeTriggerRatio: CGFloat = 0.9

    private var bubbleShape: UnevenRoundedRectangle {
        let full = DesignConstants.CornerRadius.bubble
        let small = DesignConstants.CornerRadius.bubbleGrouped
        if message.isUser {
            return UnevenRoundedRectangle(
                topLeadingRadius: full,
                bottomLeadingRadius: full,
                bottomTrailingRadius: isLastInGroup ? full : small,
                topTrailingRadius: isFirstInGroup ? full : small
            )
        } else {
            return UnevenRoundedRectangle(
                topLeadingRadius: isFirstInGroup ? full : small,
                bottomLeadingRadius: isLastInGroup ? full : small,
                bottomTrailingRadius: full,
                topTrailingRadius: full
            )
        }
    }

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
                // Assistant avatar label
                if !message.isUser && isFirstInGroup {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: DesignConstants.BubbleStyle.avatarSize, height: DesignConstants.BubbleStyle.avatarSize)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Circle())
                        Text("PocketMind")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                // Thinking disclosure (assistant only)
                if !message.isUser, let thinking = message.thinkingContent {
                    ThinkingDisclosure(content: thinking, isThinking: message.isThinking, isExpanded: $thinkingExpanded)
                } else if !message.isUser && message.isThinking {
                    // Think tag detected but no content yet — show pill immediately
                    ThinkingDisclosure(content: "", isThinking: true, isExpanded: $thinkingExpanded)
                }

                // Main bubble — action block stripped; shown as pill below
                let bubbleText = message.displayContent
                let displayText = (isStreaming && !message.isUser) ? bubbleText + " ▍" : bubbleText
                if !bubbleText.isEmpty {
                    bubbleTextView(displayText, isUser: message.isUser)
                        .padding(.horizontal, DesignConstants.Padding.bubbleHorizontal)
                        .padding(.vertical, DesignConstants.Padding.bubbleVertical)
                        .background(
                            message.isUser
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [DesignConstants.BubbleStyle.userGradientTop, DesignConstants.BubbleStyle.userGradientBottom],
                                    startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(Color(.systemBackground))
                        )
                        .foregroundStyle(message.isUser ? .white : .primary)
                        .clipShape(bubbleShape)
                        .overlay {
                            if !message.isUser {
                                bubbleShape
                                    .strokeBorder(Color(.systemGray4), lineWidth: 1)
                            }
                        }
                        .shadow(color: message.isUser ? DesignConstants.BubbleStyle.userShadowColor : .black.opacity(0.06),
                                radius: message.isUser ? DesignConstants.BubbleStyle.userShadowRadius : 4,
                                x: 0, y: message.isUser ? DesignConstants.BubbleStyle.userShadowY : 2)
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

                    // Image thumbnails for user messages with image attachments
                    if message.isUser && !message.imageAttachments.isEmpty {
                        imageThumbnails(message.imageAttachments, isUserMessage: message.isUser)
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
                        onConfirm: { onConfirmDeletion?(preview.id) },
                        onCancel: { onCancelDeletion?(preview.id) },
                        onUndo: { onUndoDeletion?(preview.id) },
                        onConfirmUpdate: { onConfirmUpdate?(preview.id) },
                        onCancelUpdate: { onCancelUpdate?(preview.id) },
                        onKeepConflict: { onKeepConflict?(preview.id) },
                        onCancelConflict: { await onCancelConflict?(preview.id) },
                        onFindFreeSlots: { await onFindFreeSlots?(preview.id) ?? [] },
                        onRescheduleToSlot: { slot in await onRescheduleToSlot?(preview.id, slot) }
                    )
                }

                // Bulk action bar when ≥2 pending deletions
                if pendingDeletionCount >= 2 {
                    BulkDeletionBar(
                        count: pendingDeletionCount,
                        onDeleteAll: { onConfirmAllDeletions?() },
                        onKeepAll: { onCancelAllDeletions?() }
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
        .opacity(appeared ? 1 : 0)
        .offset(
            x: reduceMotion ? 0 : (appeared ? 0 : (message.isUser ? 8 : -8)),
            y: reduceMotion ? 0 : (appeared ? 0 : 12)
        )
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(DesignConstants.Anim.messageFadeIn) { appeared = true }
            }
        }
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
