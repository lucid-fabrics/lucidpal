import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel

    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !viewModel.isModelLoaded {
                    modelNotLoadedBanner
                }
                messageList
                inputBar
            }
            .navigationTitle("PocketMind")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !viewModel.messages.isEmpty {
                        Button("Clear") { viewModel.clearHistory() }
                            .foregroundStyle(.secondary)
                    }
                }
            }
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
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.messages.count, perform: { _ in
                scrollToBottom(proxy: proxy)
            })
            .onChange(of: viewModel.messages.last?.content, perform: { _ in
                scrollToBottom(proxy: proxy)
            })
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
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
                    Task { await viewModel.sendMessage() }
                    inputFocused = false
                }
            } label: {
                Image(systemName: viewModel.isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(sendButtonColor)
            }
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
