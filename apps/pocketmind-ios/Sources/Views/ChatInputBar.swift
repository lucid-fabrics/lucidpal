import OSLog
import PhotosUI
import SwiftUI

private let chatInputBarLogger = Logger(subsystem: "app.pocketmind", category: "ChatInputBar")

/// Standalone chat input bar with optional photo attachment button and image thumbnail strip.
struct ChatInputBar: View {
    @Binding var text: String
    let imageAttachments: [AttachedImage]
    let isSpeechAvailable: Bool
    let isSpeechRecording: Bool
    let isSpeechTranscribing: Bool
    let isGenerating: Bool
    let isPreparing: Bool
    let isModelLoaded: Bool
    let onSend: () -> Void
    let onMicToggle: () -> Void
    let onAddImage: (UIImage) -> Void
    let onRemoveImage: (UUID) -> Void

    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @FocusState private var isFocused: Bool

    private let thumbnailSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 0) {
            // Image thumbnail strip
            if !imageAttachments.isEmpty {
                thumbnailStrip
            }

            // Main input row
            HStack(spacing: 10) {
                if isSpeechAvailable {
                    Button {
                        isFocused = false
                        onMicToggle()
                    } label: {
                        MicButtonLabel(
                            isRecording: isSpeechRecording,
                            isTranscribing: isSpeechTranscribing
                        )
                    }
                    .disabled(isSpeechTranscribing)
                }

                // Photo attachment button
                Button {
                    showPhotoPicker = true
                } label: {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.accentColor)
                }

                TextField("Ask about your schedule…", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .focused($isFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                sendButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .top) { Divider() }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                do {
                    if let data = try await newItem.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        onAddImage(image)
                    }
                } catch {
                    chatInputBarLogger.error("Failed to load photo transferable: \(error.localizedDescription, privacy: .public)")
                }
                selectedPhotoItem = nil
            }
        }
    }

    private var sendButton: some View {
        let isEmpty = text.trimmingCharacters(in: .whitespaces).isEmpty && imageAttachments.isEmpty
        let sendButtonColor: Color = isEmpty ? Color(.systemGray3) : Color.accentColor
        return Button {
            onSend()
            isFocused = false
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(sendButtonColor)
        }
        .disabled(!isModelLoaded)
        .disabled(isGenerating || isPreparing)
        .disabled(isEmpty)
    }

    private var thumbnailStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(imageAttachments) { attachment in
                    ZStack(alignment: .topTrailing) {
                        if let thumbData = attachment.thumbnailData,
                           let uiImage = UIImage(data: thumbData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: thumbnailSize, height: thumbnailSize)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                                .frame(width: thumbnailSize, height: thumbnailSize)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                }
                        }

                        // Remove button
                        Button {
                            onRemoveImage(attachment.id)
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
            .padding(.vertical, 6)
        }
        .background(Color(.systemBackground))
    }
}
