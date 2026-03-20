import Foundation

// MARK: - Token streaming + toast notifications
// Separated from the core ViewModel to keep each file under 400 lines.

extension ChatViewModel {

    func showToast(_ message: String, systemImage: String) {
        toast = ToastItem(message: message, systemImage: systemImage)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5)) // safe: cancellation discarded intentionally
            self?.toast = nil
        }
    }

    /// Applies one streamed token to the assistant message at `idx`, handling
    /// the <think>...</think> wrapper that Qwen3 emits before its response.
    func applyStreamToken(
        _ token: String,
        rawBuffer: inout String,
        thinkDone: inout Bool,
        showThinking: Bool,
        idx: Int
    ) {
        rawBuffer += token
        if thinkDone {
            messages[idx].content += token
        } else if rawBuffer.hasPrefix("<think>") {
            if let closeRange = rawBuffer.range(of: "</think>") {
                let thinkText = String(rawBuffer[rawBuffer.index(rawBuffer.startIndex, offsetBy: "<think>".count) ..< closeRange.lowerBound])
                let response  = String(rawBuffer[closeRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if showThinking {
                    messages[idx].thinkingContent = thinkText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                messages[idx].isThinking = false
                messages[idx].content = response
                thinkDone = true
            } else {
                // Still inside <think> — buffer or show depending on setting
                if showThinking {
                    messages[idx].isThinking = true
                    messages[idx].thinkingContent = String(rawBuffer.dropFirst("<think>".count))
                }
            }
        } else if "<think>".hasPrefix(rawBuffer) {
            // Still buffering opening tag — don't display yet
        } else {
            thinkDone = true
            messages[idx].content = rawBuffer
        }
    }
}
