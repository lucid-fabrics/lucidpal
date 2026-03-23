import SwiftUI
import UIKit

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel

    @FocusState var inputFocused: Bool
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
