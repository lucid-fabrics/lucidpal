import Foundation
import llama

// MARK: - Tokenize & Decode

extension LlamaActor {
    func tokenize(text: String, addBOS: Bool, parseSpecial: Bool, vocab: OpaquePointer) -> [llama_token] {
        let utf8Count = text.utf8.count
        let maxTokens = utf8Count + (addBOS ? 1 : 0) + 1
        let buf = UnsafeMutablePointer<llama_token>.allocate(capacity: maxTokens)
        defer { buf.deallocate() }
        let n = llama_tokenize(vocab, text, Int32(utf8Count), buf, Int32(maxTokens), addBOS, parseSpecial)
        guard n > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: buf, count: Int(n)))
    }

    // MARK: - Token to String

    func tokenToPiece(token: llama_token, vocab: OpaquePointer) -> [CChar] {
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

    func decodeUTF8(_ chars: [CChar]) -> String {
        appendPendingChars(chars)
        let pending = getPendingChars()
        if let str = String(validatingUTF8: pending + [0]) {
            clearPending()
            return str
        }
        for len in stride(from: pending.count - 1, through: 1, by: -1)
            where String(validatingUTF8: Array(pending.suffix(len)) + [0]) != nil {
            let str = String(cString: pending + [0])
            clearPending()
            return str
        }
        return ""
    }

    // MARK: - Batch helpers

    func batchClear() { clearBatch() }

    func batchAdd(id: llama_token, pos: Int32, seqId: llama_seq_id, logits: Bool) {
        addToBatch(id: id, pos: pos, seqId: seqId, logits: logits)
    }
}
