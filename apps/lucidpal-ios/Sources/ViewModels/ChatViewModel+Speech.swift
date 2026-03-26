import Foundation

@MainActor
extension ChatViewModel {

    func toggleSpeech() {
        if speechService.isRecording {
            confirmSpeech()
        } else {
            discardNextTranscript = false
            do {
                try speechService.startRecording()
                hapticService.impact(.light)
            } catch {
                errorMessage = "Microphone error: \(error.localizedDescription)"
            }
        }
    }

    /// Stops recording and accepts the transcript. Auto-sends if the setting is enabled.
    func confirmSpeech() {
        guard speechService.isRecording else { return }
        voiceAutoStartActive = false
        speechService.stopRecording()
    }

    /// Stops recording and discards the transcript. Never auto-sends.
    func cancelSpeech() {
        guard speechService.isRecording else { return }
        suppressSpeechAutoSend = true
        discardNextTranscript = true
        voiceAutoStartActive = false
        speechService.stopRecording()
    }
}
