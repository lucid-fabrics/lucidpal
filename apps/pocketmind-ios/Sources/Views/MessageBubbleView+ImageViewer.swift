import OSLog
import SwiftUI
import UIKit

private let imageBubbleLogger = Logger(subsystem: "app.pocketmind", category: "MessageBubble")

private enum AnimationConstants {
    static let dotInitialOpacity: Double = 0.2
}

// MARK: - Markdown bubble text

/// Renders message text with inline markdown (bold, italic, code, links).
/// Converts leading `- ` list markers to `•` before parsing.
/// Falls back to plain text if AttributedString parsing fails.
@ViewBuilder
func bubbleTextView(_ text: String, isUser: Bool) -> some View {
    let processed = text
        .components(separatedBy: "\n")
        .map { line -> String in
            if line.hasPrefix("* ") { return "• " + line.dropFirst(2) }
            if line.hasPrefix("- ") { return "• " + line.dropFirst(2) }
            return line
        }
        .joined(separator: "\n")
    let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
    if let attributed = try? AttributedString(markdown: processed, options: options) {
        Text(attributed)
    } else {
        Text(processed)
    }
}

// MARK: - Generating status view

struct GeneratingStatusView: View {
    var userPrompt: String? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dotOpacity: Double = 1
    @State private var phaseIndex: Int = 0

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
        if searchKeywords.contains(where: { prompt.contains($0) }) { return .webSearch }
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
        .onAppear { if !reduceMotion { dotOpacity = AnimationConstants.dotInitialOpacity } }
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

// MARK: - Image thumbnails helper

@ViewBuilder
func imageThumbnails(_ attachments: [AttachedImage], isUserMessage: Bool) -> some View {
    ImageThumbnailsView(attachments: attachments, isUserMessage: isUserMessage)
}

// MARK: - Image thumbnails

struct ImageThumbnailsView: View {
    let attachments: [AttachedImage]
    let isUserMessage: Bool
    @State private var fullscreenImage: UIImage?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(attachments) { attachment in
                    if let thumbnailData = attachment.thumbnailData,
                       let uiImage = UIImage(data: thumbnailData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .onTapGesture {
                                fullscreenImage = loadFullImage(attachment)
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(width: 56, height: 56)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(Color(.systemGray3))
                            }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: isUserMessage ? .trailing : .leading)
        .fullScreenCover(isPresented: Binding(
            get: { fullscreenImage != nil },
            set: { if !$0 { fullscreenImage = nil } }
        )) {
            if let image = fullscreenImage {
                FullscreenImageView(image: image) {
                    fullscreenImage = nil
                }
            }
        }
    }

    private func loadFullImage(_ attachment: AttachedImage) -> UIImage? {
        if FileManager.default.fileExists(atPath: attachment.localURL.path) {
            do {
                let data = try Data(contentsOf: attachment.localURL)
                if let image = UIImage(data: data) {
                    return image
                }
            } catch {
                imageBubbleLogger.error("Failed to load full image from disk: \(error.localizedDescription, privacy: .public)")
            }
        }
        if !attachment.base64Data.isEmpty,
           let data = Data(base64Encoded: attachment.base64Data),
           let image = UIImage(data: data) {
            return image
        }
        if let data = attachment.thumbnailData {
            return UIImage(data: data)
        }
        return nil
    }
}

// MARK: - Fullscreen image viewer

struct FullscreenImageView: View {
    let image: UIImage
    let onDismiss: () -> Void
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnifyGesture()
                        .onChanged { value in
                            scale = lastScale * value.magnification
                        }
                        .onEnded { _ in
                            lastScale = max(scale, 1.0)
                            scale = lastScale
                            if scale <= 1.0 {
                                offset = .zero
                                lastOffset = .zero
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1.0 {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            lastOffset = offset
                        }
                )
                .onTapGesture {
                    onDismiss()
                }
        }
        .statusBarHidden()
    }
}
