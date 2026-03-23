import SwiftUI

extension ChatView {

    @ViewBuilder
    var errorBanner: some View {
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

    var modelNotLoadedBanner: some View {
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

    var autoListeningBanner: some View {
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

    var emptyState: some View {
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
}
