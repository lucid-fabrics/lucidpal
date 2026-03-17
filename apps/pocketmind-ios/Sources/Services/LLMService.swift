import Foundation
import SwiftLlama

@MainActor
final class LLMService: ObservableObject {
    @Published private(set) var isLoaded = false
    @Published private(set) var isGenerating = false

    private var llama: SwiftLlama?
    private var currentTask: Task<Void, Never>?

    func loadModel(at url: URL) async throws {
        do {
            llama = try SwiftLlama(modelPath: url.path)
            isLoaded = true
        } catch {
            throw LLMError.loadFailed(underlying: error)
        }
    }

    func unloadModel() {
        cancelGeneration()
        llama = nil
        isLoaded = false
    }

    func cancelGeneration() {
        currentTask?.cancel()
        currentTask = nil
        isGenerating = false
    }

    func generate(prompt: String) -> AsyncThrowingStream<String, Error> {
        // Guard concurrent calls before creating the stream
        guard !isGenerating else {
            return AsyncThrowingStream { $0.finish(throwing: LLMError.generationInProgress) }
        }
        guard let llama else {
            return AsyncThrowingStream { $0.finish(throwing: LLMError.modelNotLoaded) }
        }

        isGenerating = true

        return AsyncThrowingStream { [weak self] continuation in
            let task = Task { [weak self] in
                defer {
                    Task { @MainActor [weak self] in
                        self?.isGenerating = false
                        self?.currentTask = nil
                    }
                }
                do {
                    for await token in llama.start(for: prompt) {
                        if Task.isCancelled {
                            continuation.finish()
                            return
                        }
                        continuation.yield(token)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            // Store task reference on MainActor for cancellation
            Task { @MainActor [weak self] in
                self?.currentTask = task
            }
        }
    }

    // MARK: - Qwen3 chat template

    static func buildPrompt(messages: [ChatMessage], systemPrompt: String? = nil) -> String {
        var parts: [String] = []

        if let system = systemPrompt, !system.isEmpty {
            parts.append("<|im_start|>system\n\(system)<|im_end|>")
        }

        for msg in messages where msg.role != .system {
            let role = msg.role == .user ? "user" : "assistant"
            parts.append("<|im_start|>\(role)\n\(msg.content)<|im_end|>")
        }

        parts.append("<|im_start|>assistant\n")
        return parts.joined(separator: "\n")
    }
}

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
        case .loadFailed(let underlying):
            return "Failed to load model: \(underlying.localizedDescription). The file may be corrupted — try deleting and re-downloading."
        }
    }
}
