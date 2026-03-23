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
    nonisolated(unsafe) private var model: OpaquePointer?   // freed in deinit
    nonisolated(unsafe) private var ctx: OpaquePointer?   // freed in deinit
    nonisolated(unsafe) private var vocab: OpaquePointer?   // freed in deinit (via model)
    nonisolated(unsafe) private var sampler: UnsafeMutablePointer<llama_sampler>? // freed in deinit
    nonisolated(unsafe) private var batch: llama_batch      // freed in deinit via llama_batch_free

    private var pendingCChars: [CChar] = []
    private var nCur: Int32 = 0

    var isLoaded: Bool { model != nil }

    init() {
        llama_backend_init()
        batch = llama_batch_init(LLMConstants.batchCapacity, 0, 1)
    }

    deinit {
        if let s = sampler { llama_sampler_free(s) }
        if let c = ctx { llama_free(c) }
        if let m = model { llama_model_free(m) }
        llama_batch_free(batch)
        llama_backend_free()
    }

    // MARK: Load / Unload

    func load(path: String, contextSize: UInt32) throws {
        unload()

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
        cp.n_batch         = contextSize  // must match n_ctx so full-prompt prefill fits in one decode call
        cp.n_threads       = nThreads
        cp.n_threads_batch = nThreads
        cp.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_ENABLED  // halves KV cache memory, speeds up prefill
        cp.offload_kqv     = true                           // keep KV cache in GPU memory

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
        if let c = ctx { llama_free(c); ctx = nil }
        if let m = model { llama_model_free(m); model = nil }
        vocab = nil
        nCur  = 0
    }

    /// Decodes a single BOS token to warm up the Metal pipeline.
    /// Eliminates the ~300 ms shader-compilation stutter on the first real user message.
    /// KV cache is cleared afterwards so the warmup has no effect on responses.
    func warmup() {
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
        // Use the actual initialised context length so the budget is correct on both the 4 K and 8 K
        // context configurations.  Previously this hard-coded smallContextSize (4096) regardless of
        // device RAM, leaving only 512 slots for generation on a 4 K device while maxNewTokens is 768,
        // causing llama_decode to assert-crash once generation went past token 4096.
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

    /// Encodes all prompt tokens into the KV cache. Returns false (and finishes the continuation with an error) on failure.
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

    /// Samples tokens one at a time and yields decoded strings until EOS, cancellation, or budget exhaustion.
    private func streamTokens(
        maxNew: Int32,
        contextLength: Int,
        ctx: OpaquePointer,
        vocab: OpaquePointer,
        sampler: UnsafeMutablePointer<llama_sampler>,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) {
        // Cap at context length so we never pass an out-of-range position to llama_decode
        // (which asserts in debug builds).
        let ctxLimit = Int32(contextLength) - 1
        let startCur = nCur
        while nCur - startCur < maxNew && nCur < ctxLimit {
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
        for len in stride(from: pendingCChars.count - 1, through: 1, by: -1)
            where String(validatingUTF8: Array(pendingCChars.suffix(len)) + [0]) != nil {
            let str = String(cString: pendingCChars + [0])
            pendingCChars = []
            return str
        }
        return ""
    }
}
