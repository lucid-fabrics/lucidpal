import SwiftUI

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
