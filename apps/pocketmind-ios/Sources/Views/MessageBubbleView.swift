import SwiftUI
import UIKit

struct MessageBubbleView: View {
    let message: ChatMessage
    var onConfirmDeletion: ((UUID) -> Void)? = nil
    var onCancelDeletion: ((UUID) -> Void)? = nil
    var onUndoDeletion: ((UUID) -> Void)? = nil
    var onConfirmUpdate: ((UUID) -> Void)? = nil
    var onCancelUpdate: ((UUID) -> Void)? = nil
    var onConfirmAllDeletions: (() -> Void)? = nil
    var onCancelAllDeletions: (() -> Void)? = nil
    var onDeleteMessage: ((UUID) -> Void)? = nil
    @State private var thinkingExpanded = false
    @State private var showTimestamp = false

    private var pendingDeletionCount: Int {
        message.calendarEventPreviews.filter { $0.state == .pendingDeletion }.count
    }

    var body: some View {
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
                        .background(message.isUser ? Color.accentColor : Color(.systemGray5))
                        .foregroundStyle(message.isUser ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.bubble, style: .continuous))
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
                    StreamingSkeletonView()
                }

                // Animated pill while action block is streaming
                if message.isStreamingAction {
                    CalendarActionPill()
                }

                // Free slot query result
                if !message.calendarFreeSlots.isEmpty {
                    CalendarQueryResultCard(slots: message.calendarFreeSlots)
                }

                // Calendar event cards
                ForEach(message.calendarEventPreviews, id: \.id) { preview in
                    CalendarEventCard(
                        preview: preview,
                        onConfirm:        { onConfirmDeletion?(preview.id) },
                        onCancel:         { onCancelDeletion?(preview.id) },
                        onUndo:           { onUndoDeletion?(preview.id) },
                        onConfirmUpdate:  { onConfirmUpdate?(preview.id) },
                        onCancelUpdate:   { onCancelUpdate?(preview.id) }
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
        }
        .padding(.horizontal, DesignConstants.Padding.messageHorizontal)
    }
}

// MARK: - Markdown bubble text


/// Renders message text with inline markdown (bold, italic, code, links).
/// Falls back to plain text if AttributedString parsing fails.
@ViewBuilder
private func bubbleTextView(_ text: String, isUser: Bool) -> some View {
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    if let attributed = try? AttributedString(markdown: text, options: options) {
        Text(attributed)
    } else {
        Text(text)
    }
}

// MARK: - Streaming skeleton

private struct StreamingSkeletonView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            skeletonLine(width: nil)
            skeletonLine(width: nil)
            skeletonLine(width: 80)
        }
        .padding(.horizontal, DesignConstants.Padding.bubbleHorizontal)
        .padding(.vertical, DesignConstants.Padding.bubbleVertical)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: DesignConstants.CornerRadius.bubble, style: .continuous))
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }

    @ViewBuilder
    private func skeletonLine(width: CGFloat?) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(shimmerGradient)
            .frame(height: 11)
            .frame(maxWidth: width ?? .infinity, alignment: .leading)
    }

    private var shimmerGradient: LinearGradient {
        LinearGradient(
            colors: [Color(.systemGray4), Color(.systemGray3), Color(.systemGray4)],
            startPoint: UnitPoint(x: phase - 0.5, y: 0.5),
            endPoint: UnitPoint(x: phase + 0.5, y: 0.5)
        )
    }
}
