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
            .background(Color.red.opacity(0.08))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red)
                    .frame(width: 3)
            }
            .overlay(alignment: .bottom) { Divider() }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    var modelNotLoadedBanner: some View {
        ModelNotLoadedBannerContent()
    }
}

// MARK: - Model not loaded banner (extracted for @State support)

private struct ModelNotLoadedBannerContent: View {
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .opacity(pulse ? 0.4 : 1.0)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                    value: pulse
                )
            Text("No model loaded — go to Settings to download one.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.orange)
                .frame(width: 3)
        }
        .onAppear { if !reduceMotion { pulse = true } }
    }
}

extension ChatView {

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
        .background(Color.green.opacity(0.08))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.green)
                .frame(width: 3)
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    var emptyState: some View {
        EmptyStateContent(
            suggestedPrompts: viewModel.suggestedPrompts,
            isLoading: viewModel.isGeneratingSuggestions
        ) { prompt in
            viewModel.inputText = prompt
            Task { await viewModel.sendMessage() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Animated empty state

private struct EmptyStateContent: View {
    let suggestedPrompts: [String]
    let isLoading: Bool
    let onPrompt: (String) -> Void

    @State private var iconAppeared = false
    @State private var titleAppeared = false
    @State private var subtitleAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor.opacity(0.8))
                .scaleEffect(iconAppeared ? 1.0 : 0.6)
                .opacity(iconAppeared ? 1 : 0)

            VStack(spacing: 6) {
                Text("PocketMind")
                    .font(.title2.weight(.semibold))
                    .opacity(titleAppeared ? 1 : 0)
                    .offset(y: reduceMotion ? 0 : (titleAppeared ? 0 : 10))

                Text("Your on-device calendar assistant.\nAll processing stays on your iPhone.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .opacity(subtitleAppeared ? 1 : 0)
                    .offset(y: reduceMotion ? 0 : (subtitleAppeared ? 0 : 10))
            }

            SuggestedPromptsView(
                prompts: suggestedPrompts,
                isLoading: isLoading,
                onSelect: onPrompt
            )
            .padding(.horizontal, 24)
            .opacity(subtitleAppeared ? 1 : 0)

            Spacer()
        }
        .onAppear {
            if reduceMotion {
                iconAppeared = true
                titleAppeared = true
                subtitleAppeared = true
            } else {
                withAnimation(DesignConstants.Anim.emptyEntrance) { iconAppeared = true }
                withAnimation(DesignConstants.Anim.emptyEntrance.delay(0.1)) { titleAppeared = true }
                withAnimation(DesignConstants.Anim.emptyEntrance.delay(0.2)) { subtitleAppeared = true }
            }
        }
    }
}
