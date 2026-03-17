import SwiftUI

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @ObservedObject var llmService: LLMService

    @FocusState private var inputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !llmService.isLoaded {
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
            .onAppear { scrollProxy = proxy }
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
                Task { await viewModel.sendMessage() }
                inputFocused = false
            } label: {
                Image(systemName: viewModel.isGenerating ? "stop.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty && !viewModel.isGenerating
                        ? Color(.systemGray3)
                        : Color.accentColor
                    )
            }
            .disabled(
                viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty
                && !viewModel.isGenerating
            )
            .disabled(!llmService.isLoaded)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = viewModel.messages.last else { return }
        withAnimation(.easeOut(duration: 0.15)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}
