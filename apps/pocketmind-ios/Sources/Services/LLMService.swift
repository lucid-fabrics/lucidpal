import Foundation
import SwiftLlama

@MainActor
final class LLMService: ObservableObject {
    @Published var isLoaded = false
    @Published var isGenerating = false

    private var llama: SwiftLlama?

    func loadModel(at url: URL) async throws {
        llama = try SwiftLlama(modelPath: url.path)
        isLoaded = true
    }

    func unloadModel() {
        llama = nil
        isLoaded = false
    }

    /// Generates tokens from a fully-formatted Qwen3 prompt string.
    /// Caller is responsible for building the `<|im_start|>...<|im_end|>` template.
    func generate(prompt: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            guard let llama else {
                continuation.finish(throwing: LLMError.modelNotLoaded)
                return
            }
            Task {
                do {
                    isGenerating = true
                    let stream = llama.start(for: prompt)
                    for await token in stream {
                        continuation.yield(token)
                    }
                    isGenerating = false
                    continuation.finish()
                } catch {
                    isGenerating = false
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Qwen3 chat template

    /// Builds a Qwen3-format prompt from a message history + optional system block.
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

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: return "No model is loaded. Please download and select a model."
        }
    }
}
