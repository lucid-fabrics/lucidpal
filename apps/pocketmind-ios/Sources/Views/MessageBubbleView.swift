import SwiftUI
import UIKit

struct MessageBubbleView: View {
    let message: ChatMessage
    @State private var thinkingExpanded = false

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

                // Main bubble
                Text(message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "…" : message.content.trimmingCharacters(in: .whitespacesAndNewlines))
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

                // Calendar event cards
                ForEach(message.calendarEventPreviews, id: \.title) { preview in
                    CalendarEventCard(preview: preview)
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

// MARK: - Calendar event card

private struct CalendarEventCard: View {
    let preview: CalendarEventPreview

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Button(action: openInCalendar) {
            HStack(spacing: 12) {
                // Calendar icon badge
                VStack(spacing: 1) {
                    Text(monthText)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                        .background(Color.red)
                    Text(dayText)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 4)
                }
                .frame(width: 44)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color(.systemGray4), lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 3) {
                    Text(preview.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(Self.timeFormatter.string(from: preview.start)) – \(Self.timeFormatter.string(from: preview.end))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let cal = preview.calendarName {
                        Text(cal)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var monthText: String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: preview.start).uppercased()
    }

    private var dayText: String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: preview.start)
    }

    private func openInCalendar() {
        // Opens Calendar app to today (iOS 18 ignores specific timestamps in calshow://)
        if let url = URL(string: "calshow://") {
            UIApplication.shared.open(url)
        }
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
