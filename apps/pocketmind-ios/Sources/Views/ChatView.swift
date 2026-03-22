import SwiftUI
import UIKit

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel

    @FocusState private var inputFocused: Bool
    @State private var showClearConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            if !viewModel.isModelLoaded {
                modelNotLoadedBanner
            }
            if viewModel.isAutoListening {
                autoListeningBanner
            }
            errorBanner
                .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
            messageList
            if viewModel.isGenerating || viewModel.isPreparing {
                stopBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if let reply = viewModel.replyingTo {
                replyPreviewBar(reply)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            inputBar
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isGenerating || viewModel.isPreparing)
        .animation(.easeInOut(duration: 0.2), value: viewModel.replyingTo?.id)
        .background(NavPopGestureDisabler())
        .overlay {
            if viewModel.isSpeechRecording {
                VoiceRecordingOverlay(
                    transcript: viewModel.inputText,
                    isTranscribing: viewModel.isSpeechTranscribing,
                    onConfirm: { viewModel.confirmSpeech() },
                    onCancel: { viewModel.cancelSpeech() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isSpeechRecording)
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
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    viewModel.thinkingEnabled.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: viewModel.thinkingEnabled ? "brain.fill" : "brain")
                            .font(.caption.weight(.medium))
                        Text("Thinking")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(viewModel.thinkingEnabled ? Color.accentColor : Color.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        viewModel.thinkingEnabled
                            ? Color.accentColor.opacity(0.12)
                            : Color(.systemGray5),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)

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
        .task {
            guard let query = viewModel.pendingInput else { return }
            viewModel.pendingInput = nil
            viewModel.inputText = query
            await viewModel.sendMessage()
        }
        .task(id: VoiceReadiness(modelLoaded: viewModel.isModelLoaded, speechAvailable: viewModel.isSpeechAvailable)) {
            guard viewModel.voiceAutoStartEnabled || viewModel.pendingVoiceStart,
                  viewModel.messages.isEmpty,
                  viewModel.isSpeechAvailable,
                  viewModel.isModelLoaded,
                  !viewModel.isSpeechRecording else { return }
            viewModel.pendingVoiceStart = false
            try? await Task.sleep(for: .milliseconds(ChatConstants.voiceAutoStartDelayMilliseconds))
            viewModel.voiceAutoStartActive = true
            viewModel.toggleSpeech()
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

    private var autoListeningBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "airpodspro")
                .foregroundStyle(.green)
            Text("AirPods connected — auto-listening active")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color(.systemGray6))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if viewModel.messages.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            if viewModel.needsDateSeparator(at: index) {
                                DateSeparatorView(date: message.timestamp)
                                    .padding(.top, index == 0 ? 0 : 4)
                            }
                            let precedingUserPrompt = viewModel.messages[..<index]
                                .last(where: { $0.role == .user })?.content
                            MessageBubbleView(
                                message: message,
                                userPrompt: precedingUserPrompt,
                                onReply: { msg in
                                    withAnimation { viewModel.replyingTo = msg }
                                    inputFocused = true
                                },
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
                                },
                                onKeepConflict: { previewID in
                                    viewModel.keepConflict(messageID: message.id, previewID: previewID)
                                },
                                onCancelConflict: { previewID in
                                    await viewModel.cancelConflict(messageID: message.id, previewID: previewID)
                                },
                                onFindFreeSlots: { previewID in
                                    await viewModel.findFreeSlotsForConflict(messageID: message.id, previewID: previewID)
                                },
                                onRescheduleToSlot: { previewID, slot in
                                    await viewModel.rescheduleConflict(messageID: message.id, previewID: previewID, to: slot)
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
            SuggestedPromptsView(
                prompts: viewModel.suggestedPrompts,
                isLoading: viewModel.isGeneratingSuggestions
            ) { prompt in
                viewModel.inputText = prompt
                Task { await viewModel.sendMessage() }
            }
            .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }

    private var stopBar: some View {
        Button {
            viewModel.cancelGeneration()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "stop.circle.fill")
                Text(viewModel.isPreparing ? "Cancel" : "Stop")
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.red, in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }

    private var inputBar: some View {
        let isEmpty = viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty
        let sendButtonColor: Color = isEmpty ? Color(.systemGray3) : .accentColor
        return HStack(spacing: 10) {
            if viewModel.isSpeechAvailable {
                Button {
                    inputFocused = false
                    viewModel.toggleSpeech()
                } label: {
                    MicButtonLabel(
                        isRecording: viewModel.isSpeechRecording,
                        isTranscribing: viewModel.isSpeechTranscribing
                    )
                }
                .disabled(viewModel.isSpeechTranscribing)
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
                if viewModel.isSpeechRecording { viewModel.toggleSpeech() }
                Task { await viewModel.sendMessage() }
                inputFocused = false
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(sendButtonColor)
            }
            .disabled(!viewModel.isModelLoaded)
            .disabled(viewModel.isGenerating || viewModel.isPreparing)
            .disabled(isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private func replyPreviewBar(_ message: ChatMessage) -> some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor)
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                Text(message.isUser ? "You" : "PocketMind")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                Text(message.displayContent.prefix(60))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Button {
                withAnimation { viewModel.replyingTo = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color(.systemGray3))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) { Divider() }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = viewModel.messages.last else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}

// MARK: - Disable swipe-back navigation

private struct NavPopGestureDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func updateUIViewController(_ vc: UIViewController, context: Context) {
        Task { @MainActor in
            vc.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
    }
}
