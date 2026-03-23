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

    func loadModel(at url: URL, contextSize: UInt32, role: ModelType) async throws {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        try await llama.loadModel(at: url.path, contextSize: contextSize, role: role)
        await llama.warmup(role: role)
        isLoaded = true
    }

    func unloadModel(role: ModelType) {
        cancelGeneration()
        let actor = llama
        Task { [weak self] in
            await actor.unloadModel(role: role)
            let textLoaded = await actor.isTextModelLoaded
            let visionLoaded = await actor.isVisionModelLoaded
            await MainActor.run {
                self?.isLoaded = textLoaded || visionLoaded
            }
        }
    }

    func unload() {
        cancelGeneration()
        let actor = llama
        Task { await actor.unload() }
        isLoaded = false
    }

    func cancelGeneration() {
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
    }

    func generate(systemPrompt: String, messages: [ChatMessage], thinkingEnabled: Bool = true, modelRole: ModelType) -> AsyncThrowingStream<String, Error> {
        guard !isGenerating else {
            return AsyncThrowingStream { $0.finish(throwing: LLMError.generationInProgress) }
        }
        guard isLoaded else {
            return AsyncThrowingStream { $0.finish(throwing: LLMError.modelNotLoaded) }
        }

        isGenerating = true

        let prompt: String
        if modelRole == .vision {
            // Build vision prompt with image tags
            prompt = Self.buildVisionPrompt(systemPrompt: systemPrompt, messages: messages, thinkingEnabled: thinkingEnabled)
        } else {
            prompt = Self.buildPrompt(systemPrompt: systemPrompt, messages: messages, thinkingEnabled: thinkingEnabled)
        }
        let llamaRef = llama

        return AsyncThrowingStream { continuation in
            let task = Task {
                defer {
                    Task { @MainActor [weak self] in
                        self?.isGenerating = false
                        self?.currentTask  = nil
                    }
                }
                await llamaRef.generate(prompt: prompt, role: modelRole, continuation: continuation)
            }
            MainActor.assumeIsolated { [weak self] in self?.currentTask = task }
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

    /// Builds a vision prompt for Qwen3.5-Vision using <|vision_start|><|image_pad|><|vision_end|> tags.
    /// Format:
    /// <|im_start|>user
    /// <|vision_start|><|image_pad|><|vision_end|>
    /// Picture 1: <|vision_start|><|image_pad|><|vision_end|>
    /// {user text}<|im_end|>
    /// <|im_start|>assistant
    private static func buildVisionPrompt(systemPrompt: String, messages: [ChatMessage], thinkingEnabled: Bool = true) -> String {
        var parts: [String] = []

        if !systemPrompt.isEmpty {
            parts.append("<|im_start|>system\n\(sanitize(systemPrompt))<|im_end|>")
        }

        // Find the last user message with image attachments
        let body = messages.filter { $0.role != .system }
        guard let lastUserMessage = body.last(where: { $0.role == .user }) else {
            return buildPrompt(systemPrompt: systemPrompt, messages: messages, thinkingEnabled: thinkingEnabled)
        }

        // Build image tags for vision model
        let imageCount = lastUserMessage.imageAttachments.count
        var imageSection = "<|vision_start|><|image_pad|><|vision_end|>\n"
        for idx in 1...imageCount {
            imageSection += "Picture \(idx): <|vision_start|><|image_pad|><|vision_end|>\n"
        }

        // System context for prior messages (without images)
        let priorMessages = body.filter { $0.id != lastUserMessage.id }
        var i = 0
        while i + 1 < priorMessages.count {
            if priorMessages[i].role == .user && priorMessages[i + 1].role == .assistant {
                parts.append("<|im_start|>user\n\(sanitize(priorMessages[i].content))<|im_end|>")
                parts.append("<|im_start|>assistant\n\(sanitize(priorMessages[i + 1].content))<|im_end|>")
                i += 2
            } else {
                i += 1
            }
        }

        // Last user message with vision images
        let suffix = thinkingEnabled ? "" : " /no_think"
        parts.append("<|im_start|>user")
        parts.append(imageSection)
        parts.append("\(sanitize(lastUserMessage.content))\(suffix)<|im_end|>")

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
