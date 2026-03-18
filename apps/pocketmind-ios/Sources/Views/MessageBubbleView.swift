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
    @State private var thinkingExpanded = false

    private var pendingDeletionCount: Int {
        message.calendarEventPreviews.filter { $0.state == .pendingDeletion }.count
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: 60) }

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
                    Text(bubbleText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(message.isUser ? Color.accentColor : Color(.systemGray5))
                        .foregroundStyle(message.isUser ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .contextMenu {
                            if !message.content.isEmpty {
                                Button {
                                    UIPasteboard.general.string = message.content
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                        }
                } else if !message.isUser && !message.isStreamingAction && message.calendarEventPreviews.isEmpty {
                    // Bubble with placeholder while non-action content streams in
                    Text("…")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray5))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                // Animated pill while action block is streaming
                if message.isStreamingAction {
                    CalendarActionPill()
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

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
        .padding(.horizontal, 12)
    }
}

// MARK: - Bulk deletion bar

private struct BulkDeletionBar: View {
    let count: Int
    let onDeleteAll: () -> Void
    let onKeepAll: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: onKeepAll) {
                Text("Keep All")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            Divider().frame(height: 36)
            Button(action: onDeleteAll) {
                Text("Delete All (\(count))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
        .buttonStyle(.plain)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.red.opacity(0.3), lineWidth: 1))
    }
}

// MARK: - Calendar action streaming pill

private struct CalendarActionPill: View {
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.caption)
                .opacity(pulse ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.7).repeatForever(), value: pulse)
            Text("Updating calendar…")
                .font(.caption)
            Spacer()
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear { pulse = true }
    }
}

// MARK: - Thinking disclosure

private struct ThinkingDisclosure: View {
    let content: String
    let isThinking: Bool      // still streaming
    @Binding var isExpanded: Bool
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if !isThinking {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain")
                        .font(.caption)
                        .opacity(isThinking ? (pulse ? 0.4 : 1.0) : 1.0)
                        .animation(isThinking ? .easeInOut(duration: 0.8).repeatForever() : .default, value: pulse)
                    Text(isThinking ? "Thinking..." : (isExpanded ? "Hide thinking" : "Thought for a moment"))
                        .font(.caption)
                    Spacer()
                    if !isThinking {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .onAppear { if isThinking { pulse = true } }
            .onChange(of: isThinking) { _, thinking in pulse = thinking }

            if isExpanded && !isThinking {
                Text(content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
