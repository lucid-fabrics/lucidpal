// swiftlint:disable file_length
import PhotosUI
import SwiftUI
import UIKit

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel

    @FocusState var inputFocused: Bool
    @State private var showClearConfirm = false
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State var showingPhotoPicker = false
    @State var selectedPhotos: [PhotosPickerItem] = []
    @State private var isNearBottom = true

    var body: some View {
        VStack(spacing: 0) {
            modelNotLoadedBanner
                .animation(.easeInOut(duration: 0.2), value: ModelBannerState(isLoaded: viewModel.isModelLoaded, isLoading: viewModel.isModelLoading))
            if viewModel.isAutoListening {
                autoListeningBanner
            }
            errorBanner
                .animation(.easeInOut(duration: 0.2), value: viewModel.errorMessage)
            if viewModel.isSearching {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Search messages…", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(.subheadline)
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            messageList
            if let reply = viewModel.replyingTo {
                replyPreviewBar(reply)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            inputBar
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSearching)
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    renameText = viewModel.sessionTitle
                    showRenameAlert = true
                } label: {
                    Text(viewModel.sessionTitle)
                        .font(.headline)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
            }
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

                Button {
                    withAnimation { viewModel.isSearching.toggle() }
                    if !viewModel.isSearching { viewModel.searchText = "" }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)

                if !viewModel.messages.isEmpty {
                    Button("Clear") { showClearConfirm = true }
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: viewModel.isGenerating) { wasGenerating, isNowGenerating in
            if wasGenerating && !isNowGenerating {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
        .confirmationDialog("Clear chat history?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) { viewModel.clearHistory() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all messages. This cannot be undone.")
        }
        .alert("Rename Chat", isPresented: $showRenameAlert) {
            TextField("Chat name", text: $renameText)
            Button("Save") {
                let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty, let id = viewModel.sessionID else { return }
                viewModel.sessionTitle = trimmed
                viewModel.sessionManager?.renameSession(id: id, title: trimmed)
            }
            Button("Cancel", role: .cancel) {}
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
                    LazyVStack(spacing: 0) {
                        // Invisible anchor to track scroll offset
                        Color.clear.frame(height: 0)
                            .id("scroll-top")
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            let info = groupInfo(at: index)

                            if viewModel.needsDateSeparator(at: index) {
                                DateSeparatorView(date: message.timestamp)
                                    .padding(.top, index == 0 ? 0 : 4)
                            }
                            MessageBubbleView(
                                message: message,
                                userPrompt: info.precedingUserPrompt,
                                isStreaming: viewModel.isGenerating && index == viewModel.messages.count - 1 && !message.isUser,
                                isFirstInGroup: info.isFirst,
                                isLastInGroup: info.isLast,
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
                            .opacity(
                                viewModel.searchText.isEmpty
                                    || message.content.localizedCaseInsensitiveContains(viewModel.searchText)
                                    ? 1 : 0.3
                            )
                            .padding(.bottom, info.spacing)
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                let distanceFromBottom = geometry.contentSize.height - geometry.contentOffset.y - geometry.containerSize.height
                return distanceFromBottom < DesignConstants.Threshold.scrollNearBottom
            } action: { _, newValue in
                withAnimation(.easeInOut(duration: 0.2)) { isNearBottom = newValue }
            }
            .onChange(of: viewModel.messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.last?.content) {
                if isNearBottom { scrollToBottom(proxy: proxy) }
            }
            .overlay(alignment: .bottom) {
                if !isNearBottom && !viewModel.messages.isEmpty {
                    Button {
                        withAnimation(.spring(duration: 0.4, bounce: 0.1)) {
                            if let last = viewModel.messages.last {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(.regularMaterial, in: Circle())
                            .premiumShadow(level: .floating)
                    }
                    .padding(.bottom, 8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(DesignConstants.Anim.pillEntrance, value: isNearBottom)
        }
    }
}

// MARK: - Message grouping

private struct MessageGroupInfo {
    let isFirst: Bool
    let isLast: Bool
    let spacing: CGFloat
    let precedingUserPrompt: String?
}

extension ChatView {
    private func groupInfo(at index: Int) -> MessageGroupInfo {
        let msgs = viewModel.messages
        let message = msgs[index]
        let prevRole = index > 0 ? msgs[index - 1].role : nil
        let nextRole = index < msgs.count - 1 ? msgs[index + 1].role : nil
        let hasSeparator = viewModel.needsDateSeparator(at: index)
        let nextHasSeparator = index < msgs.count - 1 && viewModel.needsDateSeparator(at: index + 1)
        let isFirst = prevRole != message.role || hasSeparator
        let isLast = nextRole != message.role || nextHasSeparator
        let spacing = isLast ? DesignConstants.Grouping.interGroupSpacing : DesignConstants.Grouping.intraGroupSpacing
        let prompt = msgs[..<index].last(where: { $0.role == .user })?.content
        return MessageGroupInfo(isFirst: isFirst, isLast: isLast, spacing: spacing, precedingUserPrompt: prompt)
    }
}

private struct ModelBannerState: Equatable { let isLoaded: Bool; let isLoading: Bool }

// MARK: - Disable swipe-back navigation

private struct NavPopGestureDisabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { UIViewController() }
    func updateUIViewController(_ vc: UIViewController, context: Context) {
        Task { @MainActor in
            vc.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
    }
}
