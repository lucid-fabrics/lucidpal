import Foundation
import llama

// MARK: - LLMService (see LlamaActor.swift for the underlying C FFI actor)

// ObservableObject intentionally omitted — LLMService is not observed directly
// by any View. State is surfaced to ViewModels via the protocol's AnyPublisher
// properties (isLoadedPublisher, isGeneratingPublisher, isLoadingPublisher).
@MainActor
final class LLMService: LLMServiceProtocol {
    @Published private(set) var isLoaded    = false
    @Published private(set) var isLoading   = false
    @Published private(set) var isGenerating = false

    private let llama = LlamaActor()
    private var currentTask: Task<Void, Never>?

    func loadModel(at url: URL, contextSize: UInt32) async throws {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        try await llama.load(path: url.path, contextSize: contextSize)
        await llama.warmup()  // pre-compiles Metal shaders — eliminates first-message stutter
        isLoaded = true
    }

    func unloadModel() {
        cancelGeneration()
        let actor = llama  // capture actor reference directly — avoids extending LLMService lifetime
        Task { await actor.unload() }
        isLoaded = false
    }

    func cancelGeneration() {
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
    }

    func generate(systemPrompt: String, messages: [ChatMessage], thinkingEnabled: Bool = true) -> AsyncThrowingStream<String, Error> {
        guard !isGenerating else {
            return AsyncThrowingStream { $0.finish(throwing: LLMError.generationInProgress) }
        }
        guard isLoaded else {
            return AsyncThrowingStream { $0.finish(throwing: LLMError.modelNotLoaded) }
        }

        isGenerating = true

        let prompt = Self.buildPrompt(systemPrompt: systemPrompt, messages: messages, thinkingEnabled: thinkingEnabled)
        let llamaRef = llama

        // AsyncThrowingStream closure runs synchronously on @MainActor (generate() is @MainActor-isolated),
        // so MainActor.assumeIsolated is safe for assigning currentTask.
        return AsyncThrowingStream { continuation in
            let task = Task {
                defer {
                    Task { @MainActor [weak self] in
                        self?.isGenerating = false
                        self?.currentTask  = nil
                    }
                }
                await llamaRef.generate(prompt: prompt, continuation: continuation)
            }
            MainActor.assumeIsolated { [weak self] in self?.currentTask = task }
            // Cancel inflight generation when caller drops the stream.
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Prompt builder (Qwen3 ChatML)

    private static func sanitize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "<|im_start|>", with: "")
            .replacingOccurrences(of: "<|im_end|>", with: "")
    }

    private static func buildPrompt(systemPrompt: String, messages: [ChatMessage], thinkingEnabled: Bool = true) -> String {
        var parts: [String] = []

        if !systemPrompt.isEmpty {
            parts.append("<|im_start|>system\n\(sanitize(systemPrompt))<|im_end|>")
        }

        let body = messages.filter { $0.role != .system }
        var i = 0
        while i + 1 < body.count {
            if body[i].role == .user && body[i + 1].role == .assistant {
                parts.append("<|im_start|>user\n\(sanitize(body[i].content))<|im_end|>")
                parts.append("<|im_start|>assistant\n\(sanitize(body[i + 1].content))<|im_end|>")
                i += 2
            } else {
                i += 1
            }
        }

        if let last = body.last(where: { $0.role == .user }) {
            let suffix = thinkingEnabled ? "" : " /no_think"
            parts.append("<|im_start|>user\n\(sanitize(last.content))\(suffix)<|im_end|>")
        }

        parts.append("<|im_start|>assistant\n")
        return parts.joined(separator: "\n")
    }
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case modelNotLoaded
    case generationInProgress
    case loadFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No model loaded. Go to Settings to download one."
        case .generationInProgress:
            return "A response is already being generated."
        case .loadFailed(let e):
            return "Failed to load model: \(e.localizedDescription)"
        }
    }
}
