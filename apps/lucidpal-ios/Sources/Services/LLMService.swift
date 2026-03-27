import Foundation
import llama
import OSLog

private let llmServiceLogger = Logger(subsystem: "app.lucidpal", category: "LLMService")

// MARK: - LLMService (see LlamaActor.swift for the underlying C FFI actor)

// ObservableObject intentionally omitted — LLMService is not observed directly
// by any View. State is surfaced to ViewModels via the protocol's AnyPublisher
// properties (isLoadedPublisher, isGeneratingPublisher, isLoadingPublisher).
@MainActor
final class LLMService: LLMServiceProtocol {
    @Published private(set) var isLoaded    = false
    @Published private(set) var isLoading   = false
    @Published private(set) var isGenerating = false
    @Published private(set) var visionLoaded = false

    /// True when the loaded text model is an integrated vision model.
    private var textModelSupportsVision = false

    private let llama = LlamaActor()
    private var currentTask: Task<Void, Never>?
    private let contextTruncatedSubject = PassthroughSubject<Void, Never>()

    var contextTruncatedPublisher: AnyPublisher<Void, Never> {
        contextTruncatedSubject.eraseToAnyPublisher()
    }

    var isVisionModelLoaded: Bool { visionLoaded || textModelSupportsVision }

    func loadModel(at url: URL, contextSize: UInt32, role: ModelType, isIntegrated: Bool, mmprojURL: URL? = nil) async throws {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        try await llama.loadModel(at: url.path, contextSize: contextSize, role: role, isIntegrated: isIntegrated, mmprojPath: mmprojURL?.path)
        await llama.warmup(role: role)
        isLoaded = true
        if role == .vision { visionLoaded = true }
        if role == .text && isIntegrated { textModelSupportsVision = true }
    }

    func unloadModel(role: ModelType) {
        cancelGeneration()
        if role == .text { textModelSupportsVision = false }
        // Eagerly reset flags so generate() is blocked immediately,
        // before the async actor unload completes.
        if role == .text { isLoaded = false }
        if role == .vision { visionLoaded = false }
        let actor = llama
        Task { [weak self] in
            await actor.unloadModel(role: role)
            let textLoaded = await actor.isTextModelLoaded
            let visionLoaded = await actor.isVisionModelLoaded
            await MainActor.run {
                self?.isLoaded = textLoaded || visionLoaded
                self?.visionLoaded = visionLoaded
            }
        }
    }

    func unload() {
        cancelGeneration()
        let actor = llama
        Task { await actor.unload() }
        isLoaded = false
        visionLoaded = false
        textModelSupportsVision = false
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
        let llamaRef = llama

        // Vision path: use mtmd for proper CLIP-based image understanding
        if modelRole == .vision {
            let body = messages.filter { $0.role != .system }
            let lastUserMessage = body.last(where: { $0.role == .user })
            let imageDataList = Self.extractImageData(from: lastUserMessage)
            let prompt = Self.buildVisionPrompt(
                systemPrompt: systemPrompt, messages: messages,
                thinkingEnabled: thinkingEnabled, imageCount: imageDataList.count)
            let truncatedSubject = contextTruncatedSubject

            return AsyncThrowingStream { continuation in
                let task = Task {
                    defer {
                        Task { @MainActor [weak self] in
                            self?.isGenerating = false
                            self?.currentTask  = nil
                        }
                    }
                    await llamaRef.generateWithImages(prompt: prompt, imageDataList: imageDataList, role: modelRole, onTruncated: {
                        Task { @MainActor in truncatedSubject.send(()) }
                    }, continuation: continuation)
                }
                MainActor.assumeIsolated { [weak self] in self?.currentTask = task }
                continuation.onTermination = { _ in task.cancel() }
            }
        }

        // Text path: standard prompt
        let prompt = Self.buildPrompt(systemPrompt: systemPrompt, messages: messages, thinkingEnabled: thinkingEnabled)
        let truncatedSubject = contextTruncatedSubject

        return AsyncThrowingStream { continuation in
            let task = Task {
                defer {
                    Task { @MainActor [weak self] in
                        self?.isGenerating = false
                        self?.currentTask  = nil
                    }
                }
                await llamaRef.generate(prompt: prompt, role: modelRole, onTruncated: {
                    Task { @MainActor in truncatedSubject.send(()) }
                }, continuation: continuation)
            }
            MainActor.assumeIsolated { [weak self] in self?.currentTask = task }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Image Data Extraction

    /// Reads JPEG data from attached image files on disk.
    private static func extractImageData(from message: ChatMessage?) -> [Data] {
        guard let message else { return [] }
        return message.imageAttachments.compactMap { attachment in
            // Read JPEG from the localURL on disk
            if FileManager.default.fileExists(atPath: attachment.localURL.path) {
                do {
                    let data = try Data(contentsOf: attachment.localURL)
                    // Clean up temp file after reading — VisionImageProcessor writes to tmp/ which
                    // is not automatically purged, so we delete it once the data is in memory.
                    try? FileManager.default.removeItem(at: attachment.localURL)
                    return data
                } catch {
                    llmServiceLogger.error("Failed to read image data from disk: \(error.localizedDescription, privacy: .private)")
                }
            }
            // Fallback: decode base64 data
            if !attachment.base64Data.isEmpty {
                return Data(base64Encoded: attachment.base64Data)
            }
            return nil
        }
    }

    // MARK: - Prompt builder (Qwen3 ChatML)

    private static func sanitize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "<|im_start|>", with: "")
            .replacingOccurrences(of: "<|im_end|>", with: "")
    }

    static func buildPrompt(systemPrompt: String, messages: [ChatMessage], thinkingEnabled: Bool = true) -> String {
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

    /// Builds a vision prompt using <__media__> markers for mtmd.
    /// Each image attachment gets one marker that mtmd replaces with CLIP embeddings.
    private static func buildVisionPrompt(systemPrompt: String, messages: [ChatMessage], thinkingEnabled: Bool = true, imageCount: Int) -> String {
        var parts: [String] = []

        // Qwen VL requires "You are a helpful assistant." to stay in conversation mode.
        // Without it, the model defaults to object detection (bbox JSON output).
        let visionSystemPrompt = systemPrompt.isEmpty ? "You are a helpful assistant." : sanitize(systemPrompt)
        parts.append("<|im_start|>system\n\(visionSystemPrompt)<|im_end|>")

        let body = messages.filter { $0.role != .system }
        guard let lastUserMessage = body.last(where: { $0.role == .user }) else {
            return buildPrompt(systemPrompt: systemPrompt, messages: messages, thinkingEnabled: thinkingEnabled)
        }

        // Prior conversation context (without images)
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

        // Last user message with image markers — no /no_think for vision (confuses the model)
        let markers = (0..<imageCount).map { _ in "<__media__>" }.joined(separator: "\n")
        parts.append("<|im_start|>user")
        if !markers.isEmpty {
            parts.append(markers)
        }
        parts.append("\(sanitize(lastUserMessage.content))<|im_end|>")

        parts.append("<|im_start|>assistant\n")
        return parts.joined(separator: "\n")
    }
}

// MARK: - Errors

enum LLMError: LocalizedError {
    case modelNotLoaded
    case generationInProgress
    case loadFailed(underlying: Error)
    case generateFailed

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "No model loaded. Go to Settings to download one."
        case .generationInProgress:
            return "A response is already being generated."
        case .loadFailed(let e):
            return "Failed to load model: \(e.localizedDescription)"
        case .generateFailed:
            return "Token generation failed. Try reloading the model."
        }
    }
}
