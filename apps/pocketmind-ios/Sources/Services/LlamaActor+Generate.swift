import Foundation
import llama
import OSLog

// MARK: - Generate (text only)

extension LlamaActor {
    func generate(prompt: String, role: ModelType, continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        let useTextSlotForVision = role == .vision && !isVisionModelLoaded && textModelSupportsVision && isTextModelLoaded
        let actualCtx: OpaquePointer?
        let actualVocab: OpaquePointer?
        let actualSampler: UnsafeMutablePointer<llama_sampler>?
        if useTextSlotForVision {
            actualCtx = textCtxPointer
            actualVocab = textVocabPointer
            actualSampler = textSamplerPointer
        } else {
            actualCtx = role == .text ? textCtxPointer : visionCtxPointer
            actualVocab = role == .text ? textVocabPointer : visionVocabPointer
            actualSampler = role == .text ? textSamplerPointer : visionSamplerPointer
        }
        let ctx = actualCtx
        let vocab = actualVocab
        let sampler = actualSampler

        guard let ctx, let vocab, let sampler else {
            continuation.finish(throwing: LLMError.modelNotLoaded)
            return
        }

        let maxNew: Int32 = LLMConstants.maxNewTokens
        let contextLength = Int(llama_n_ctx(ctx))
        let maxPromptTokens = contextLength - Int(maxNew)

        var tokens = tokenize(text: prompt, addBOS: true, parseSpecial: true, vocab: vocab)
        guard !tokens.isEmpty else {
            continuation.finish()
            return
        }

        if tokens.count > Int(LLMConstants.batchCapacity) {
            continuation.finish(throwing: LLMError.loadFailed(underlying: NSError(
                domain: "llama", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Prompt too large for batch (\(tokens.count) tokens, max \(LLMConstants.batchCapacity))"])))
            return
        }

        if tokens.count > maxPromptTokens {
            tokens = Array(tokens.suffix(maxPromptTokens))
        }

        llama_memory_clear(llama_get_memory(ctx), false)
        clearPending()
        resetCursor()

        guard prefill(tokens: tokens, ctx: ctx, continuation: continuation) else { return }
        streamTokens(maxNew: maxNew, contextLength: contextLength, ctx: ctx, vocab: vocab, sampler: sampler, continuation: continuation)
        continuation.finish()
    }

    // MARK: - Generate with Images (mtmd)

    /// Creates mtmd bitmaps from raw JPEG data buffers.
    func createBitmaps(from imageDataList: [Data], mtmdCtx: OpaquePointer) throws -> [OpaquePointer] {
        var bitmaps: [OpaquePointer] = []
        for imageData in imageDataList {
            let bitmap: OpaquePointer? = imageData.withUnsafeBytes { rawBuf in
                guard let baseAddr = rawBuf.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return nil }
                return mtmd_helper_bitmap_init_from_buf(mtmdCtx, baseAddr, rawBuf.count)
            }
            guard let bitmap else {
                bitmaps.forEach { mtmd_bitmap_free($0) }
                throw LLMError.loadFailed(underlying: NSError(
                    domain: "mtmd", code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to decode image for vision model"]))
            }
            bitmaps.append(bitmap)
        }
        return bitmaps
    }

    /// Tokenizes a prompt with image bitmaps into mtmd input chunks.
    func tokenizeWithImages(prompt: String, bitmaps: [OpaquePointer], mtmdCtx: OpaquePointer) throws -> OpaquePointer {
        guard let chunks = mtmd_input_chunks_init() else {
            throw LLMError.loadFailed(underlying: NSError(
                domain: "mtmd", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Failed to init input chunks"]))
        }

        var textInput = prompt.withCString { cStr -> mtmd_input_text in
            mtmd_input_text(text: cStr, add_special: true, parse_special: true)
        }

        let bitmapPtrs: [OpaquePointer?] = bitmaps.map { Optional($0) }
        let nBitmaps = bitmapPtrs.count
        let tokenizeResult: Int32
        if bitmapPtrs.isEmpty {
            tokenizeResult = mtmd_tokenize(mtmdCtx, chunks, &textInput, nil, 0)
        } else {
            var ptrs = bitmapPtrs
            tokenizeResult = ptrs.withUnsafeMutableBufferPointer { buf in
                return mtmd_tokenize(mtmdCtx, chunks, &textInput, buf.baseAddress, nBitmaps)
            }
        }

        guard tokenizeResult == 0 else {
            mtmd_input_chunks_free(chunks)
            throw LLMError.loadFailed(underlying: NSError(
                domain: "mtmd", code: Int(tokenizeResult),
                userInfo: [NSLocalizedDescriptionKey: "mtmd_tokenize failed: \(tokenizeResult == 1 ? "bitmap count mismatch" : "image preprocessing error")"]))
        }

        return chunks
    }

    /// Generates a response using mtmd for proper CLIP-based image understanding.
    func generateWithImages(prompt: String, imageDataList: [Data], role: ModelType, continuation: AsyncThrowingStream<String, Error>.Continuation) async {
        let logger = Logger(subsystem: "app.pocketmind", category: "LlamaActor")

        let ctx = textCtxPointer
        let vocab = textVocabPointer
        let sampler = textSamplerPointer

        guard let ctx, let vocab, let sampler else {
            logger.error("generateWithImages: missing ctx/vocab/sampler")
            continuation.finish(throwing: LLMError.modelNotLoaded)
            return
        }

        guard let mtmdCtx = mtmdCtxPointer else {
            logger.warning("generateWithImages: mtmd not available, falling back to text-only")
            await generate(prompt: prompt, role: .text, continuation: continuation)
            return
        }

        llama_memory_clear(llama_get_memory(ctx), false)
        clearPending()
        resetCursor()

        let bitmaps: [OpaquePointer]
        do {
            bitmaps = try createBitmaps(from: imageDataList, mtmdCtx: mtmdCtx)
        } catch {
            continuation.finish(throwing: error)
            return
        }
        defer { bitmaps.forEach { mtmd_bitmap_free($0) } }

        let chunks: OpaquePointer
        do {
            chunks = try tokenizeWithImages(prompt: prompt, bitmaps: bitmaps, mtmdCtx: mtmdCtx)
        } catch {
            continuation.finish(throwing: error)
            return
        }
        defer { mtmd_input_chunks_free(chunks) }

        let nChunks = mtmd_input_chunks_size(chunks)
        let totalTokens = mtmd_helper_get_n_tokens(chunks)
        let ctxSize = llama_n_ctx(ctx)
        logger.info("generateWithImages: chunks=\(nChunks) totalTokens=\(totalTokens) ctxSize=\(ctxSize) useMRoPE=\(mtmd_decode_use_mrope(mtmdCtx))")

        var newNPast: Int32 = 0
        let nBatch: Int32 = 2048
        let evalResult = mtmd_helper_eval_chunks(mtmdCtx, ctx, chunks, 0, 0, nBatch, true, &newNPast)

        guard evalResult == 0 else {
            logger.error("generateWithImages: mtmd_helper_eval_chunks failed with \(evalResult), chunks=\(nChunks) totalTokens=\(totalTokens) ctxSize=\(ctxSize)")
            continuation.finish(throwing: LLMError.loadFailed(underlying: NSError(
                domain: "mtmd", code: Int(evalResult),
                userInfo: [NSLocalizedDescriptionKey: "Vision encoding failed (chunks=\(nChunks), tokens=\(totalTokens), ctx=\(ctxSize), err=\(evalResult))"])))
            return
        }

        setCursor(newNPast)
        logger.info("generateWithImages: eval done, n_past=\(newNPast)")

        let maxNew: Int32 = LLMConstants.maxNewTokens
        let contextLength = Int(llama_n_ctx(ctx))
        streamTokens(maxNew: maxNew, contextLength: contextLength, ctx: ctx, vocab: vocab, sampler: sampler, continuation: continuation)
        continuation.finish()
    }

    /// Encodes all prompt tokens into the KV cache.
    func prefill(tokens: [llama_token], ctx: OpaquePointer, continuation: AsyncThrowingStream<String, Error>.Continuation) -> Bool {
        batchClear()
        for (i, tok) in tokens.enumerated() {
            batchAdd(id: tok, pos: Int32(i), seqId: 0, logits: i == tokens.count - 1)
        }
        guard llama_decode(ctx, currentBatch) == 0 else {
            continuation.finish(throwing: LLMError.loadFailed(underlying: NSError(
                domain: "llama", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Prefill decode failed"])))
            return false
        }
        llama_synchronize(ctx)
        setCursor(currentBatch.n_tokens)
        return true
    }

    /// Samples tokens one at a time and yields decoded strings.
    func streamTokens(
        maxNew: Int32,
        contextLength: Int,
        ctx: OpaquePointer,
        vocab: OpaquePointer,
        sampler: UnsafeMutablePointer<llama_sampler>,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) {
        let ctxLimit = Int32(contextLength) - 1
        let startCur = currentCursor
        while currentCursor - startCur < maxNew && currentCursor < ctxLimit {
            if Task.isCancelled { break }

            let newTok = llama_sampler_sample(sampler, ctx, -1)
            if llama_vocab_is_eog(vocab, newTok) { break }

            let piece = tokenToPiece(token: newTok, vocab: vocab)
            let str = decodeUTF8(piece)
            if !str.isEmpty { continuation.yield(str) }

            batchClear()
            batchAdd(id: newTok, pos: currentCursor, seqId: 0, logits: true)
            advanceCursor()

            guard llama_decode(ctx, currentBatch) == 0 else { break }
            llama_synchronize(ctx)
        }

        flushPending(continuation: continuation)
    }
}
