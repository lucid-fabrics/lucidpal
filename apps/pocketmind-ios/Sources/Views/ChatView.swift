import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel

    @FocusState private var inputFocused: Bool
    @State private var errorDismissTask: Task<Void, Never>?
    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.isModelLoaded {
                modelNotLoadedBanner
            }
            errorBanner
                .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
            messageList
            inputBar
        }
        .overlay(alignment: .bottom) {
            if let toast = viewModel.toast {
                ToastView(item: toast)
                    .padding(.bottom, 72)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: viewModel.toast)
        .navigationTitle(viewModel.sessionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !viewModel.messages.isEmpty {
                    Button("Clear") { showClearConfirm = true }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog("Clear chat history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) { viewModel.clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all messages. This cannot be undone.")
        }
        .onChange(of: viewModel.errorMessage) { _, msg in
            errorDismissTask?.cancel()
            guard msg != nil else { return }
            errorDismissTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(5))
                viewModel.errorMessage = nil
            }
        }
        .onDisappear { errorDismissTask?.cancel() }
        .task {
            guard let query = viewModel.pendingInput else { return }
            viewModel.pendingInput = nil
            viewModel.inputText = query
            await viewModel.sendMessage()
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = viewModel.errorMessage {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                Spacer()
                Button {
                    viewModel.errorMessage = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .overlay(alignment: .bottom) { Divider() }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var modelNotLoadedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text("No model loaded — go to Settings to download one.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            let prev = index > 0 ? viewModel.messages[index - 1] : nil
                            if needsDateSeparator(current: message, previous: prev) {
                                DateSeparatorView(date: message.timestamp)
                                    .padding(.top, index == 0 ? 0 : 4)
                            }
                            MessageBubbleView(
                                message: message,
                                onConfirmDeletion: { previewID in
                                    Task { await viewModel.confirmDeletion(messageID: message.id, previewID: previewID) }
                                },
                                onCancelDeletion: { previewID in
                                    viewModel.cancelDeletion(messageID: message.id, previewID: previewID)
                                },
                                onUndoDeletion: { previewID in
                                    Task { await viewModel.undoDeletion(messageID: message.id, previewID: previewID) }
                                },
                                onConfirmUpdate: { previewID in
                                    Task { await viewModel.confirmUpdate(messageID: message.id, previewID: previewID) }
                                },
                                onCancelUpdate: { previewID in
                                    viewModel.cancelUpdate(messageID: message.id, previewID: previewID)
                                },
                                onConfirmAllDeletions: {
                                    Task { await viewModel.confirmAllDeletions(messageID: message.id) }
                                },
                                onCancelAllDeletions: {
                                    viewModel.cancelAllDeletions(messageID: message.id)
                                },
                                onDeleteMessage: { msgID in
                                    viewModel.deleteMessage(id: msgID)
                                }
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .onChange(of: viewModel.messages.count, perform: { _ in
                scrollToBottom(proxy: proxy)
            })
            .onChange(of: viewModel.messages.last?.content, perform: { _ in
                scrollToBottom(proxy: proxy)
            })
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor.opacity(0.8))
            VStack(spacing: 6) {
                Text("PocketMind")
                    .font(.title2.weight(.semibold))
                Text("Your on-device calendar assistant.\nAll processing stays on your iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            VStack(spacing: 10) {
                ForEach(suggestedPrompts, id: \.self) { prompt in
                    Button {
                        viewModel.inputText = prompt
                        inputFocused = true
                    } label: {
                        Text(prompt)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    private let suggestedPrompts = [
        "What's on my calendar this week?",
        "Add a meeting tomorrow at 2pm",
        "Find a free 1-hour slot today",
        "Delete my next dentist appointment",
    ]

    private func needsDateSeparator(current: ChatMessage, previous: ChatMessage?) -> Bool {
        guard let previous else { return true }
        return !Calendar.current.isDate(current.timestamp, inSameDayAs: previous.timestamp)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            if viewModel.isSpeechAvailable {
                Button {
                    viewModel.toggleSpeech()
                } label: {
                    MicButtonLabel(isRecording: viewModel.isSpeechRecording)
                }
            }

            TextField("Ask about your schedule…", text: $viewModel.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button {
                if viewModel.isGenerating {
                    viewModel.cancelGeneration()
                } else {
                    if viewModel.isSpeechRecording { viewModel.toggleSpeech() }
                    Task { await viewModel.sendMessage() }
                    inputFocused = false
                }
            } label: {
                if viewModel.isPreparing {
                    Image(systemName: "hourglass.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.orange)
                } else {
                    Image(systemName: viewModel.isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(sendButtonColor)
                }
            }
            .disabled(viewModel.isPreparing)
            .disabled(!viewModel.isModelLoaded && !viewModel.isGenerating)
            .disabled(
                viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                && !viewModel.isGenerating
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) { Divider() }
    }

    private var sendButtonColor: Color {
        if viewModel.isGenerating { return .red }
        if viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty { return Color(.systemGray3) }
        return .accentColor
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = viewModel.messages.last else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}

// MARK: - Mic button label

private struct MicButtonLabel: View {
    let isRecording: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ring1Scale: CGFloat = 1
    @State private var ring2Scale: CGFloat = 1

    var body: some View {
        ZStack {
            if isRecording && !reduceMotion {
                Circle()
                    .stroke(Color.red.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 40, height: 40)
                    .scaleEffect(ring1Scale)
                Circle()
                    .stroke(Color.red.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 40, height: 40)
                    .scaleEffect(ring2Scale)
            }
            Image(systemName: isRecording ? "mic.fill" : "mic")
                .font(.system(size: 22))
                .foregroundStyle(isRecording ? .red : Color(.systemGray))
        }
        .frame(width: 40, height: 40)
        .onChange(of: isRecording) { _, recording in
            if recording {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { ring1Scale = 1.5 }
                withAnimation(.easeInOut(duration: 0.9).delay(0.3).repeatForever(autoreverses: true)) { ring2Scale = 1.7 }
            } else {
                ring1Scale = 1
                ring2Scale = 1
            }
        }
        .onAppear {
            if isRecording && !reduceMotion {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { ring1Scale = 1.5 }
                withAnimation(.easeInOut(duration: 0.9).delay(0.3).repeatForever(autoreverses: true)) { ring2Scale = 1.7 }
            }
        }
    }
}

// MARK: - Date separator

private struct DateSeparatorView: View {
    let date: Date

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        Text(Self.formatter.string(from: date))
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
    }
}
