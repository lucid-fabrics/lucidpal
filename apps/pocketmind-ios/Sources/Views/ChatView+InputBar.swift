import OSLog
import PhotosUI
import SwiftUI

private let inputBarLogger = Logger(subsystem: "app.pocketmind", category: "ChatInputBar")

extension ChatView {

    var stopBar: some View {
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

    var inputBar: some View {
        let isEmpty = viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty
        let hasImages = !viewModel.imageAttachments.isEmpty
        let sendButtonColor: Color = (isEmpty && !hasImages) ? Color(.systemGray3) : .accentColor
        return VStack(spacing: 0) {
            // Thumbnail strip for image attachments
            if hasImages {
                imageAttachmentStrip
            }

            HStack(spacing: 10) {
                // Photo attachment button
                Button {
                    showingPhotoPicker = true
                } label: {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 22))
                        .foregroundStyle(Color(.systemGray))
                }
                .disabled(viewModel.isGenerating || viewModel.isPreparing)

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
                    ZStack {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                        if hasImages {
                            Image(systemName: "vision")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .offset(x: 8, y: 8)
                        }
                    }
                    .foregroundStyle(sendButtonColor)
                }
                .disabled(!viewModel.isModelLoaded)
                .disabled(viewModel.isGenerating || viewModel.isPreparing)
                .disabled(isEmpty && !hasImages)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) { Divider() }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotos, maxSelectionCount: 5, matching: .images)
        .onChange(of: selectedPhotos) { _, newValue in
            Task {
                await handleSelectedPhotos(newValue)
            }
        }
    }

    @ViewBuilder
    private var imageAttachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.imageAttachments) { attachment in
                    ZStack(alignment: .topTrailing) {
                        if let thumbnailData = attachment.thumbnailData,
                           let uiImage = UIImage(data: thumbnailData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: 60, height: 60)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(Color(.systemGray3))
                                }
                        }

                        Button {
                            viewModel.removeImageAttachment(id: attachment.id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(.white, Color.black.opacity(0.6))
                        }
                        .offset(x: 4, y: -4)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6).opacity(0.5))
    }

    private func handleSelectedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await processImage(uiImage)
                }
            } catch {
                inputBarLogger.error("Failed to load photo transferable: \(error.localizedDescription, privacy: .public)")
            }
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        selectedPhotos = []
    }

    private func processImage(_ uiImage: UIImage) async {
        await MainActor.run {
            let processor = VisionImageProcessor()
            do {
                let result = try processor.process(uiImage)
                viewModel.addImageAttachment(result)
            } catch {
                inputBarLogger.error("Failed to process image for attachment: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    @ViewBuilder
    func replyPreviewBar(_ message: ChatMessage) -> some View {
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

    func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = viewModel.messages.last else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}
