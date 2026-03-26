import Foundation
import llama
import OSLog

// MARK: - Constants

enum LLMConstants {
    /// Token capacity for the llama batch — must match the largest context size so that
    /// a full-prompt prefill on a high-RAM (8 K context) device never overflows the buffer.
    static let batchCapacity: Int32 = 8192
    /// Context size for devices with < 6 GB RAM.
    static let smallContextSize: UInt32 = 4096
    /// Context size for devices with >= 6 GB RAM (4B model tier).
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
    /// llama.cpp treats any value >= the model's actual layer count as "all layers".
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

    // Multimodal (mtmd) context for CLIP image encoding
    nonisolated(unsafe) private var mtmdCtx: OpaquePointer?

    // Shared batch (used by both models)
    nonisolated(unsafe) private var batch: llama_batch

    private var pendingCChars: [CChar] = []
    private var nCur: Int32 = 0

    // Current active role
    private var activeRole: ModelType?

    /// True when the text model is an integrated vision model (handles both text and vision).
    private(set) var textModelSupportsVision: Bool = false

    var isTextModelLoaded: Bool { textModel != nil }
    var isVisionModelLoaded: Bool { visionModel != nil }

    var isLoaded: Bool { textModel != nil || visionModel != nil }

    // MARK: - Internal accessors for extensions

    var textCtxPointer: OpaquePointer? { textCtx }
    var textVocabPointer: OpaquePointer? { textVocab }
    var textSamplerPointer: UnsafeMutablePointer<llama_sampler>? { textSampler }
    var visionCtxPointer: OpaquePointer? { visionCtx }
    var visionVocabPointer: OpaquePointer? { visionVocab }
    var visionSamplerPointer: UnsafeMutablePointer<llama_sampler>? { visionSampler }
    var mtmdCtxPointer: OpaquePointer? { mtmdCtx }
    var currentBatch: llama_batch { batch }
    var currentCursor: Int32 { nCur }

    func setCursor(_ value: Int32) { nCur = value }
    func advanceCursor() { nCur += 1 }
    func resetCursor() { nCur = 0 }

    func clearPending() { pendingCChars = [] }
    func appendPendingChars(_ chars: [CChar]) { pendingCChars.append(contentsOf: chars) }
    func getPendingChars() -> [CChar] { pendingCChars }

    func flushPending(continuation: AsyncThrowingStream<String, Error>.Continuation) {
        if !pendingCChars.isEmpty {
            let str = String(cString: pendingCChars + [0])
            if !str.isEmpty { continuation.yield(str) }
            pendingCChars = []
        }
    }

    func clearBatch() { batch.n_tokens = 0 }

    func addToBatch(id: llama_token, pos: Int32, seqId: llama_seq_id, logits: Bool) {
        let i = Int(batch.n_tokens)
        guard i < LLMConstants.batchCapacity else { return }
        batch.token   [i] = id
        batch.pos     [i] = pos
        batch.n_seq_id[i] = 1
        if let ptr = batch.seq_id[i] { ptr[0] = seqId }
        batch.logits  [i] = logits ? 1 : 0
        batch.n_tokens += 1
    }

    // MARK: - Init / Deinit

    init() {
        llama_backend_init()
        batch = llama_batch_init(LLMConstants.batchCapacity, 0, 1)
    }

    deinit {
        if let m = mtmdCtx { mtmd_free(m) }
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
    func loadModel(at path: String, contextSize: UInt32, role: ModelType, isIntegrated: Bool = false, mmprojPath: String? = nil) throws {
        let logger = Logger(subsystem: "app.lucidpal", category: "LlamaActor")
        logger.info("loadModel: path=\(path) role=\(String(describing: role)) isIntegrated=\(isIntegrated) mmproj=\(mmprojPath ?? "none")")
        if role == .vision && deviceRAMGB < LLMConstants.visionModelMinRAMGB && textModel != nil {
            unloadModel(role: .text)
        }

        switch role {
        case .text:
            try loadSingleModel(at: path, contextSize: contextSize, role: role, into: &textModel, &textCtx, &textVocab, &textSampler)
            textModelSupportsVision = isIntegrated

            if let mmprojPath, let model = textModel {
                if let existingMtmd = mtmdCtx {
                    mtmd_free(existingMtmd)
                    mtmdCtx = nil
                }
                var params = mtmd_context_params_default()
                params.use_gpu = true
                params.n_threads = max(1, min(Int32(LLMConstants.maxThreadCount), Int32(ProcessInfo.processInfo.processorCount - 2)))
                params.flash_attn_type = LLAMA_FLASH_ATTN_TYPE_ENABLED
                let ctx = mtmd_init_from_file(mmprojPath, model, params)
                if let ctx {
                    mtmdCtx = ctx
                    logger.info("loadModel: mtmd context initialized, vision=\(mtmd_support_vision(ctx))")
                } else {
                    logger.error("loadModel: mtmd_init_from_file failed for mmproj=\(mmprojPath)")
                }
            }

            logger.info("loadModel: text slot loaded, textModelSupportsVision=\(self.textModelSupportsVision)")
        case .vision:
            try loadSingleModel(at: path, contextSize: contextSize, role: role, into: &visionModel, &visionCtx, &visionVocab, &visionSampler)
            logger.info("loadModel: vision slot loaded, visionModel=\(self.visionModel != nil)")
        }
        activeRole = role
    }

    private func loadSingleModel(
        at path: String,
        contextSize: UInt32,
        role: ModelType,
        into modelPtr: inout OpaquePointer?,
        _ ctxPtr: inout OpaquePointer?,
        _ vocabPtr: inout OpaquePointer?,
        _ samplerPtr: inout UnsafeMutablePointer<llama_sampler>?
    ) throws {
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
        cp.n_batch         = role == .vision ? min(contextSize, UInt32(LLMConstants.batchCapacity)) : contextSize
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
            if let m = mtmdCtx { mtmd_free(m); mtmdCtx = nil }
            if let s = textSampler { llama_sampler_free(s); textSampler = nil }
            if let c = textCtx { llama_free(c); textCtx = nil }
            if let m = textModel { llama_model_free(m); textModel = nil }
            textVocab = nil
            textModelSupportsVision = false
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
        clearBatch()
        addToBatch(id: bos, pos: 0, seqId: 0, logits: false)
        _ = llama_decode(ctx, batch)
        llama_synchronize(ctx)
        llama_memory_clear(llama_get_memory(ctx), false)
        nCur = 0
    }
}
