import Foundation
import llama

// MARK: - Constants

enum LLMConstants {
    /// Token capacity for the llama batch — must match the largest context size so that
    /// a full-prompt prefill on a high-RAM (8 K context) device never overflows the buffer.
    static let batchCapacity: Int32 = 8192
    /// Context size for devices with < 6 GB RAM.
    static let smallContextSize: UInt32 = 4096
    /// Context size for devices with ≥ 6 GB RAM (4B model tier).
    static let largeContextSize: UInt32 = 8192
    /// RAM threshold (GB) for selecting the larger context window.
    static let largeContextRAMThresholdGB = 6
    /// Maximum thread count offered to llama.cpp.
    /// Capped at 4 — on Apple Silicon the performance cores are a minority and
    /// extra threads add synchronization overhead, especially with Metal GPU offload active.
    static let maxThreadCount: Int32 = 4
    /// Maximum tokens to generate per response.
    static let maxNewTokens: Int32 = 768
    /// Sampler temperature: lower = more deterministic, fewer hallucinated fields.
    static let samplerTemperature: Float = 0.35
    /// Bytes in one gigabyte — used for RAM-based context sizing.
    static let bytesPerGB: UInt64 = 1_073_741_824
    /// GPU layers value that offloads the entire model to Metal on-device.
    /// llama.cpp treats any value ≥ the model's actual layer count as "all layers".
    static let allMetalGPULayers: Int32 = 99
    /// RAM threshold for vision model loading — if device has less than this and a text
    /// model is already loaded, unload the text model first.
    static let visionModelMinRAMGB: Int = 6
}

// MARK: - ModelType

/// Role of the model in the dual-model architecture.
enum ModelType: Sendable {
    case text
    case vision
}

// MARK: - LlamaActor

/// Serial actor that owns all llama.cpp C state.
/// Every llama C API call happens on this actor's executor.
///
/// C pointer properties are marked `nonisolated(unsafe)` so `deinit` (which is
/// nonisolated in Swift 6) can free them. All *writes* happen exclusively from
/// actor-isolated methods, so there is no concurrent access in practice.
actor LlamaActor {
    // Safety: These C pointers are only ever read or written inside actor-isolated methods
    // (load, unload, generate, batchAdd, etc.), guaranteeing serial access during the
    // object's lifetime. `nonisolated(unsafe)` is required solely so that `deinit`
    // (which is nonisolated in Swift 6) can call the llama C free functions; by the time
    // deinit runs no other code holds a reference to this actor, so there is no concurrent
    // access.

    // Text model pointers
    nonisolated(unsafe) private var textModel: OpaquePointer?
    nonisolated(unsafe) private var textCtx: OpaquePointer?
    nonisolated(unsafe) private var textVocab: OpaquePointer?
    nonisolated(unsafe) private var textSampler: UnsafeMutablePointer<llama_sampler>?

    // Vision model pointers
    nonisolated(unsafe) private var visionModel: OpaquePointer?
    nonisolated(unsafe) private var visionCtx: OpaquePointer?
    nonisolated(unsafe) private var visionVocab: OpaquePointer?
    nonisolated(unsafe) private var visionSampler: UnsafeMutablePointer<llama_sampler>?

    // Shared batch (used by both models)
    nonisolated(unsafe) private var batch: llama_batch

    private var pendingCChars: [CChar] = []
    private var nCur: Int32 = 0

    // Current active role
    private var activeRole: ModelType?

    var isTextModelLoaded: Bool { textModel != nil }
    var isVisionModelLoaded: Bool { visionModel != nil }

    var isLoaded: Bool { textModel != nil || visionModel != nil }

    init() {
        llama_backend_init()
        batch = llama_batch_init(LLMConstants.batchCapacity, 0, 1)
    }

    deinit {
        if let s = textSampler { llama_sampler_free(s) }
        if let c = textCtx { llama_free(c) }
        if let m = textModel { llama_model_free(m) }
        if let s = visionSampler { llama_sampler_free(s) }
        if let c = visionCtx { llama_free(c) }
        if let m = visionModel { llama_model_free(m) }
        llama_batch_free(batch)
        llama_backend_free()
    }

    // MARK: - Device RAM

    private var deviceRAMGB: Int {
        Int(ProcessInfo.processInfo.physicalMemory / LLMConstants.bytesPerGB)
    }

    // MARK: - Load / Unload

    /// Loads a model for the given role. If loading a vision model on a low-RAM device
    /// with the text model already loaded, unloads the text model first.
    func loadModel(at path: String, contextSize: UInt32, role: ModelType) throws {
        // RAM guard: vision model needs enough RAM. If loading vision on < 6GB device
        // with text model already loaded, unload text model first.
        if role == .vision && deviceRAMGB < LLMConstants.visionModelMinRAMGB && textModel != nil {
            unloadModel(role: .text)
        }

        switch role {
        case .text:
            try loadSingleModel(at: path, contextSize: contextSize, into: &textModel, &textCtx, &textVocab, &textSampler)
        case .vision:
            try loadSingleModel(at: path, contextSize: contextSize, into: &visionModel, &visionCtx, &visionVocab, &visionSampler)
        }
        activeRole = role
    }

    private func loadSingleModel(
        at path: String,
        contextSize: UInt32,
        into modelPtr: inout OpaquePointer?,
        _ ctxPtr: inout OpaquePointer?,
        _ vocabPtr: inout OpaquePointer?,
        _ samplerPtr: inout UnsafeMutablePointer<llama_sampler>?
    ) throws {
        // Free existing model of same role if any
        if let s = samplerPtr { llama_sampler_free(s); samplerPtr = nil }
        if let c = ctxPtr { llama_free(c); ctxPtr = nil }
        if let m = modelPtr { llama_model_free(m); modelPtr = nil }

        var mp = llama_model_default_params()
#if targetEnvironment(simulator)
        mp.n_gpu_layers = 0
#else
        mp.n_gpu_layers = LLMConstants.allMetalGPULayers
#endif
        guard let m = llama_model_load_from_file(path, mp) else {
            throw LLMError.loadFailed(underlying: NSError(
                domain: "llama", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "llama_model_load_from_file returned nil — file may be unsupported or corrupted."]))
        }

        let nThreads = max(1, min(LLMConstants.maxThreadCount, Int32(ProcessInfo.processInfo.processorCount - 2)))
        var cp = llama_context_default_params()
        cp.n_ctx           = contextSize
        cp.n_batch         = contextSize
        cp.n_threads       = nThreads
        cp.n_threads_batch = nThreads
        cp.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_ENABLED
        cp.offload_kqv     = true

        guard let c = llama_init_from_model(m, cp) else {
            llama_model_free(m)
            throw LLMError.loadFailed(underlying: NSError(
                domain: "llama", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "llama_init_from_model returned nil — not enough memory?"]))
        }

        modelPtr = m
        ctxPtr   = c
        vocabPtr = llama_model_get_vocab(m)

        let sparams = llama_sampler_chain_default_params()
        let s = llama_sampler_chain_init(sparams)
        llama_sampler_chain_add(s, llama_sampler_init_temp(LLMConstants.samplerTemperature))
        llama_sampler_chain_add(s, llama_sampler_init_dist(UInt32.random(in: 0...UInt32.max)))
        samplerPtr = s
    }

    /// Unloads the model for the given role.
    func unloadModel(role: ModelType) {
        switch role {
        case .text:
            if let s = textSampler { llama_sampler_free(s); textSampler = nil }
            if let c = textCtx { llama_free(c); textCtx = nil }
            if let m = textModel { llama_model_free(m); textModel = nil }
            textVocab = nil
        case .vision:
            if let s = visionSampler { llama_sampler_free(s); visionSampler = nil }
            if let c = visionCtx { llama_free(c); visionCtx = nil }
            if let m = visionModel { llama_model_free(m); visionModel = nil }
            visionVocab = nil
        }
        if activeRole == role { activeRole = nil }
        nCur = 0
    }

    /// Unloads all models.
    func unload() {
        unloadModel(role: .text)
        unloadModel(role: .vision)
        pendingCChars = []
        nCur = 0
    }

    /// Decodes a single BOS token to warm up the Metal pipeline.
    func warmup(role: ModelType) {
        let ctx = role == .text ? textCtx : visionCtx
        let vocab = role == .text ? textVocab : visionVocab
        guard let ctx, let vocab else { return }
        let bos = llama_vocab_bos(vocab)
        guard bos >= 0 else { return }
        batchClear()
        batchAdd(id: bos, pos: 0, seqId: 0, logits: false)
        _ = llama_decode(ctx, batch)
        llama_synchronize(ctx)
        llama_memory_clear(llama_get_memory(ctx), false)
        nCur = 0
    }

    // MARK: - Generate

    func generate(prompt: String, role: ModelType, continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        let ctx = role == .text ? textCtx : visionCtx
        let vocab = role == .text ? textVocab : visionVocab
        let sampler = role == .text ? textSampler : visionSampler

        guard let ctx, let vocab, let sampler else {
            continuation.finish(throwing: LLMError.modelNotLoaded)
            return
        }

        var tokens = tokenize(text: prompt, addBOS: true, parseSpecial: true, vocab: vocab)
        guard !tokens.isEmpty else {
            continuation.finish()
            return
        }

        let maxNew: Int32 = LLMConstants.maxNewTokens
        let contextLength = Int(llama_n_ctx(ctx))
        let maxPromptTokens = contextLength - Int(maxNew)
        if tokens.count > maxPromptTokens {
            tokens = Array(tokens.suffix(maxPromptTokens))
        }

        llama_memory_clear(llama_get_memory(ctx), false)
        pendingCChars = []
        nCur = 0

        guard prefill(tokens: tokens, ctx: ctx, continuation: continuation) else { return }
        streamTokens(maxNew: maxNew, contextLength: contextLength, ctx: ctx, vocab: vocab, sampler: sampler, continuation: continuation)
        continuation.finish()
    }

    /// Encodes all prompt tokens into the KV cache.
    private func prefill(tokens: [llama_token], ctx: OpaquePointer, continuation: AsyncThrowingStream<String, Error>.Continuation) -> Bool {
        batchClear()
        for (i, tok) in tokens.enumerated() {
            batchAdd(id: tok, pos: Int32(i), seqId: 0, logits: i == tokens.count - 1)
        }
        guard llama_decode(ctx, batch) == 0 else {
            continuation.finish(throwing: LLMError.loadFailed(underlying: NSError(
                domain: "llama", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Prefill decode failed"])))
            return false
        }
        llama_synchronize(ctx)
        nCur = batch.n_tokens
        return true
    }

    /// Samples tokens one at a time and yields decoded strings.
    private func streamTokens(
        maxNew: Int32,
        contextLength: Int,
        ctx: OpaquePointer,
        vocab: OpaquePointer,
        sampler: UnsafeMutablePointer<llama_sampler>,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) {
        let ctxLimit = Int32(contextLength) - 1
        let startCur = nCur
        while nCur - startCur < maxNew && nCur < ctxLimit {
            if Task.isCancelled { break }

            let newTok = llama_sampler_sample(sampler, ctx, -1)
            if llama_vocab_is_eog(vocab, newTok) { break }

            let piece = tokenToPiece(token: newTok, vocab: vocab)
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
    }

    // MARK: - Batch helpers

    private func batchClear() { batch.n_tokens = 0 }

    private func batchAdd(id: llama_token, pos: Int32, seqId: llama_seq_id, logits: Bool) {
        let i = Int(batch.n_tokens)
        batch.token   [i] = id
        batch.pos     [i] = pos
        batch.n_seq_id[i] = 1
        if let ptr = batch.seq_id[i] { ptr[0] = seqId }
        batch.logits  [i] = logits ? 1 : 0
        batch.n_tokens += 1
    }

    // MARK: - Tokenize

    private func tokenize(text: String, addBOS: Bool, parseSpecial: Bool, vocab: OpaquePointer) -> [llama_token] {
        let utf8Count = text.utf8.count
        let maxTokens = utf8Count + (addBOS ? 1 : 0) + 1
        let buf = UnsafeMutablePointer<llama_token>.allocate(capacity: maxTokens)
        defer { buf.deallocate() }
        let n = llama_tokenize(vocab, text, Int32(utf8Count), buf, Int32(maxTokens), addBOS, parseSpecial)
        guard n > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: buf, count: Int(n)))
    }

    // MARK: - Token → String

    private func tokenToPiece(token: llama_token, vocab: OpaquePointer) -> [CChar] {
        var buf = [CChar](repeating: 0, count: 8)
        let n = llama_token_to_piece(vocab, token, &buf, 8, 0, false)
        if n < 0 {
            let bufSize = Int(-Int(n))
            guard bufSize <= 65_536 else { return [] }
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
        for len in stride(from: pendingCChars.count - 1, through: 1, by: -1)
            where String(validatingUTF8: Array(pendingCChars.suffix(len)) + [0]) != nil {
            let str = String(cString: pendingCChars + [0])
            pendingCChars = []
            return str
        }
        return ""
    }
}
