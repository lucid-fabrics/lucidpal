import Foundation
import llama

// MARK: - LlamaActor

/// Serial actor that owns all llama.cpp C state.
/// Every llama C API call happens on this actor's executor.
///
/// C pointer properties are marked `nonisolated(unsafe)` so `deinit` (which is
/// nonisolated in Swift 6) can free them. All *writes* happen exclusively from
/// actor-isolated methods, so there is no concurrent access in practice.
// MARK: - Constants

private enum LLMConstants {
    /// Token capacity for the llama batch (matches max context size).
    static let batchCapacity: Int32 = 4096
    /// Context size for devices with < 6 GB RAM.
    static let smallContextSize: UInt32 = 4096
    /// Context size for devices with ≥ 6 GB RAM (4B model tier).
    static let largeContextSize: UInt32 = 8192
    /// RAM threshold (GB) for selecting the larger context window.
    static let largeContextRAMThresholdGB = 6
    /// Maximum thread count offered to llama.cpp.
    static let maxThreadCount: Int32 = 8
    /// Tokens reserved for generation — subtracted from context to size the prompt budget.
    static let generationReserveTokens = 512
    /// Maximum tokens to generate per response.
    static let maxNewTokens: Int32 = 768
    /// Sampler temperature: lower = more deterministic, fewer hallucinated fields.
    static let samplerTemperature: Float = 0.35
}

actor LlamaActor {
    // nonisolated(unsafe): deinit is nonisolated in Swift 6 — must free C pointers there.
    // All writes happen exclusively from actor-isolated methods; no concurrent access.
    nonisolated(unsafe) private var model:   OpaquePointer?   // freed in deinit
    nonisolated(unsafe) private var ctx:     OpaquePointer?   // freed in deinit
    nonisolated(unsafe) private var vocab:   OpaquePointer?   // freed in deinit (via model)
    nonisolated(unsafe) private var sampler: UnsafeMutablePointer<llama_sampler>? // freed in deinit
    nonisolated(unsafe) private var batch:   llama_batch      // freed in deinit via llama_batch_free

    private var pendingCChars: [CChar] = []
    private var nCur: Int32 = 0

    var isLoaded: Bool { model != nil }

    init() {
        llama_backend_init()
        batch = llama_batch_init(LLMConstants.batchCapacity, 0, 1)
    }

    deinit {
        if let s = sampler { llama_sampler_free(s) }
        if let c = ctx     { llama_free(c) }
        if let m = model   { llama_model_free(m) }
        llama_batch_free(batch)
        llama_backend_free()
    }

    // MARK: Load / Unload

    func load(path: String) throws {
        unload()

        var mp = llama_model_default_params()
#if targetEnvironment(simulator)
        mp.n_gpu_layers = 0
#endif
        guard let m = llama_model_load_from_file(path, mp) else {
            throw LLMError.loadFailed(underlying: NSError(
                domain: "llama", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "llama_model_load_from_file returned nil — file may be unsupported or corrupted."]))
        }

        let nThreads = Int32(max(1, min(LLMConstants.maxThreadCount, ProcessInfo.processInfo.processorCount - 2)))
        // Use 8 K context on devices with ≥6 GB RAM (4B model tier); 4 K otherwise.
        let ramGB = Int(ProcessInfo.processInfo.physicalMemory / 1_073_741_824)
        var cp = llama_context_default_params()
        cp.n_ctx           = ramGB >= LLMConstants.largeContextRAMThresholdGB ? LLMConstants.largeContextSize : LLMConstants.smallContextSize
        cp.n_threads       = nThreads
        cp.n_threads_batch = nThreads

        guard let c = llama_init_from_model(m, cp) else {
            llama_model_free(m)
            throw LLMError.loadFailed(underlying: NSError(
                domain: "llama", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "llama_init_from_model returned nil — not enough memory?"]))
        }

        model = m
        ctx   = c
        vocab = llama_model_get_vocab(m)

        let sparams = llama_sampler_chain_default_params()
        let s = llama_sampler_chain_init(sparams)
        // Lower temperature for a calendar assistant: reduces hallucinated JSON fields
        // and date/time errors. 0.35 keeps variety in prose while keeping actions precise.
        llama_sampler_chain_add(s, llama_sampler_init_temp(LLMConstants.samplerTemperature))
        llama_sampler_chain_add(s, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))
        sampler = s
    }

    func unload() {
        if let s = sampler { llama_sampler_free(s); sampler = nil }
        if let c = ctx     { llama_free(c);         ctx     = nil }
        if let m = model   { llama_model_free(m);   model   = nil }
        vocab = nil
        nCur  = 0
    }

    // MARK: Generate

    func generate(prompt: String, continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        guard let ctx, let vocab, let sampler else {
            continuation.finish(throwing: LLMError.modelNotLoaded)
            return
        }

        var tokens = tokenize(text: prompt, addBOS: true, parseSpecial: true)
        guard !tokens.isEmpty else {
            continuation.finish()
            return
        }

        // Guard against context overflow — truncate from the front, keeping the most recent tokens.
        let maxPromptTokens = Int(LLMConstants.smallContextSize) - LLMConstants.generationReserveTokens
        if tokens.count > maxPromptTokens {
            tokens = Array(tokens.suffix(maxPromptTokens))
        }

        llama_memory_clear(llama_get_memory(ctx), false)
        pendingCChars = []
        nCur = 0

        // Prefill
        batchClear()
        for (i, tok) in tokens.enumerated() {
            batchAdd(id: tok, pos: Int32(i), seqId: 0, logits: i == tokens.count - 1)
        }
        guard llama_decode(ctx, batch) == 0 else {
            continuation.finish(throwing: LLMError.loadFailed(underlying: NSError(
                domain: "llama", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Prefill decode failed"])))
            return
        }
        llama_synchronize(ctx)
        nCur = batch.n_tokens

        // Generation loop
        let maxNew: Int32 = LLMConstants.maxNewTokens
        while nCur - Int32(tokens.count) < maxNew {
            if Task.isCancelled { break }

            let newTok = llama_sampler_sample(sampler, ctx, -1)
            if llama_vocab_is_eog(vocab, newTok) { break }

            let piece = tokenToPiece(token: newTok)
            let str   = decodeUTF8(piece)
            if !str.isEmpty { continuation.yield(str) }

            batchClear()
            batchAdd(id: newTok, pos: nCur, seqId: 0, logits: true)
            nCur += 1

            guard llama_decode(ctx, batch) == 0 else { break }
            llama_synchronize(ctx)
        }

        if !pendingCChars.isEmpty {
            let str = String(cString: pendingCChars + [0])
            if !str.isEmpty { continuation.yield(str) }
            pendingCChars = []
        }

        continuation.finish()
    }

    // MARK: - Batch helpers

    private func batchClear() { batch.n_tokens = 0 }

    private func batchAdd(id: llama_token, pos: Int32, seqId: llama_seq_id, logits: Bool) {
        let i = Int(batch.n_tokens)
        batch.token   [i] = id
        batch.pos     [i] = pos
        batch.n_seq_id[i] = 1
        if let ptr = batch.seq_id[i] { ptr[0] = seqId }  // Guard: seq_id[i] should always be non-nil after llama_batch_init
        batch.logits  [i] = logits ? 1 : 0
        batch.n_tokens += 1
    }

    // MARK: - Tokenize

    private func tokenize(text: String, addBOS: Bool, parseSpecial: Bool) -> [llama_token] {
        guard let vocab else { return [] }
        let utf8Count = text.utf8.count
        let maxTokens = utf8Count + (addBOS ? 1 : 0) + 1
        let buf = UnsafeMutablePointer<llama_token>.allocate(capacity: maxTokens)
        defer { buf.deallocate() }
        let n = llama_tokenize(vocab, text, Int32(utf8Count), buf, Int32(maxTokens), addBOS, parseSpecial)
        guard n > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: buf, count: Int(n)))
    }

    // MARK: - Token → String

    private func tokenToPiece(token: llama_token) -> [CChar] {
        guard let vocab else { return [] }
        var buf = [CChar](repeating: 0, count: 8)
        let n = llama_token_to_piece(vocab, token, &buf, 8, 0, false)
        if n < 0 {
            // Cast to Int before negating to avoid Int32 overflow when n == Int32.min
            let bufSize = Int(-Int(n))
            guard bufSize <= 65_536 else { return [] }  // Sanity: no token piece > 64 KB
            var big = [CChar](repeating: 0, count: bufSize)
            let n2 = llama_token_to_piece(vocab, token, &big, Int32(bufSize), 0, false)
            return Array(big.prefix(Int(n2)))
        }
        return Array(buf.prefix(Int(n)))
    }

    private func decodeUTF8(_ chars: [CChar]) -> String {
        pendingCChars.append(contentsOf: chars)
        if let str = String(validatingUTF8: pendingCChars + [0]) {
            pendingCChars = []
            return str
        }
        for len in stride(from: pendingCChars.count - 1, through: 1, by: -1) {
            if String(validatingUTF8: Array(pendingCChars.suffix(len)) + [0]) != nil {
                let str = String(cString: pendingCChars + [0])
                pendingCChars = []
                return str
            }
        }
        return ""
    }
}

// MARK: - LLMService

@MainActor
final class LLMService: ObservableObject {
    @Published private(set) var isLoaded    = false
    @Published private(set) var isLoading   = false
    @Published private(set) var isGenerating = false

    private let llama = LlamaActor()
    private var currentTask: Task<Void, Never>?

    func loadModel(at url: URL) async throws {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        try await llama.load(path: url.path)
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
