import AVFoundation
import Combine
import Foundation
import OSLog
@preconcurrency import WhisperKit

private let whisperLogger = Logger(subsystem: "app.pocketmind", category: "Whisper")

private enum RecordingError: Error, LocalizedError {
    case failedToStart
    var errorDescription: String? { "Audio hardware refused to start recording. Try again." }
}

/// Speech-to-text service backed by WhisperKit (openai_whisper-tiny, on-device).
///
/// Uses AVAudioRecorder (not AVAudioEngine) to avoid malloc on the real-time
/// audio render thread, which is a common source of EXC_BAD_ACCESS on iOS.
///
/// Recording lifecycle:
///  - startRecording() → AVAudioRecorder captures audio to a temp .m4a file.
///  - stopRecording()  → recorder stops; isRecording stays *true* while WhisperKit
///    transcribes the file so ChatViewModel's auto-send observer fires only after
///    inputText is populated from transcriptPublisher.
///  - transcribeAndFinish(_:) → calls kit.transcribe(audioPath:), sets transcript,
///    then sets isRecording = false.
@MainActor
final class WhisperSpeechService {

    @Published private(set) var isRecording = false
    @Published private(set) var isAuthorized = false
    @Published private(set) var transcript = ""
    @Published private(set) var transcriptionError: String?

    private var whisperKit: WhisperKit?
    private var recorder: AVAudioRecorder?
    private var silenceTimer: Timer?
    // Prevents re-entry into stopRecording while transcription is in progress.
    @Published private(set) var isTranscribing = false

    private static let silenceTimeoutSeconds: TimeInterval = 30
    private static let whisperKitPollIntervalMilliseconds: Int64 = 100
    private static let recordingURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("pm_whisper_input.wav")

    // MARK: - SpeechServiceProtocol

    func requestAuthorization() async {
        let granted = await Self.askMicrophonePermission()
        guard granted else { return }
        // Mark authorized immediately so the recording UI can appear without waiting
        // for WhisperKit to finish loading. The model loads in parallel; it will be
        // ready well before the user finishes speaking.
        isAuthorized = true
        await loadWhisperKit()
    }

    func startRecording() throws {
        guard isAuthorized, !isRecording, !isTranscribing else { return }

        let session = AVAudioSession.sharedInstance()
        // .default mode keeps AGC active — critical for WhisperKit to hear quiet voice.
        // .measurement disabled AGC which caused near-silence recordings → [BLANK_AUDIO].
        try session.setCategory(.record, mode: .default, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        // Record as 16 kHz mono LinearPCM WAV — the native format WhisperKit
        // feeds to the model. AAC at 16 kHz caused the OS to resample from
        // 44.1 kHz producing silent segments that WhisperKit returned as "".
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]

        // Remove stale file from a prior session so the new recorder starts clean.
        do {
            try FileManager.default.removeItem(at: Self.recordingURL)
        } catch {
            // Stale recording file may not exist; log and continue
            whisperLogger.debug("WhisperSpeech: could not remove stale recording: \(error)")
        }

        do {
            let rec = try AVAudioRecorder(url: Self.recordingURL, settings: settings)
            let started = rec.record()
            DebugLogStore.shared.log("AVAudioRecorder.record() returned \(started)", category: "Whisper")
            guard started else {
                try? session.setActive(false, options: .notifyOthersOnDeactivation)  // best-effort
                throw RecordingError.failedToStart
            }
            recorder = rec
        } catch {
            do {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            } catch let deactivationError {
                whisperLogger.error("Failed to deactivate audio session after recording error: \(deactivationError)")
            }
            DebugLogStore.shared.log("startRecording failed: \(error.localizedDescription)", category: "Whisper", level: .error)
            throw error
        }

        transcript = ""
        transcriptionError = nil
        isRecording = true
        DebugLogStore.shared.log("Recording started — isRecording=true", category: "Whisper")

        silenceTimer = Timer.scheduledTimer(
            withTimeInterval: Self.silenceTimeoutSeconds,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.stopRecording() }
        }
    }

    func stopRecording() {
        guard isRecording, !isTranscribing else {
            DebugLogStore.shared.log("stopRecording() skipped — isRecording=\(isRecording) isTranscribing=\(isTranscribing)", category: "Whisper")
            return
        }
        silenceTimer?.invalidate()
        silenceTimer = nil

        recorder?.stop()
        recorder = nil

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            whisperLogger.error("Audio session deactivation failed: \(error)")
        }

        // isRecording stays true during transcription so ChatViewModel's
        // auto-send observer fires only after transcript has been set.
        isTranscribing = true
        DebugLogStore.shared.log("Recording stopped — transcribing started", category: "Whisper")
        Task { [weak self] in await self?.transcribeAndFinish(Self.recordingURL) }
    }

    // MARK: - Private

    private func loadWhisperKit() async {
        DebugLogStore.shared.log("WhisperKit loading model: openai_whisper-tiny", category: "Whisper")
        do {
            whisperKit = try await WhisperKit(model: "openai_whisper-tiny")
            isAuthorized = true
            whisperLogger.info("WhisperKit ready")
            DebugLogStore.shared.log("WhisperKit ready", category: "Whisper")
        } catch {
            whisperLogger.error("WhisperKit init failed: \(error)")
            DebugLogStore.shared.log("WhisperKit failed to load: \(error.localizedDescription)", category: "Whisper", level: .error)
            transcriptionError = "Speech model failed to load. Check your internet connection and retry."
        }
    }

    private func transcribeAndFinish(_ url: URL) async {
        transcriptionError = nil
        defer {
            isRecording = false
            isTranscribing = false
            DebugLogStore.shared.log("transcribeAndFinish done — isRecording=false isTranscribing=false", category: "Whisper")
        }

        DebugLogStore.shared.log("transcribeAndFinish started", category: "Whisper")

        // Wait up to 5 s for WhisperKit if it's still loading (e.g. very short recording).
        let deadline = Date.now.addingTimeInterval(5)
        while whisperKit == nil, Date.now < deadline {
            try? await Task.sleep(for: .milliseconds(Self.whisperKitPollIntervalMilliseconds))
        }
        guard let kit = whisperKit else {
            let msg = "Speech model not ready — try again in a moment."
            whisperLogger.error("WhisperKit not ready after timeout — dropping transcription")
            DebugLogStore.shared.log("WhisperKit nil after 5s wait", category: "Whisper", level: .error)
            transcriptionError = msg
            return
        }

        // safe: failure is handled by the guard's else branch — error is logged, transcription is skipped
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attrs[.size] as? Int else {
            whisperLogger.error("WhisperSpeech: could not read recording file attributes")
            transcriptionError = "Recording file missing — microphone may not have started."
            return
        }
        DebugLogStore.shared.log("Recording file size: \(fileSize) bytes at \(url.lastPathComponent)", category: "Whisper")

        // WAV at 16 kHz 16-bit mono = 32 KB/s. Require at least 0.5 s (~16 KB).
        guard FileManager.default.fileExists(atPath: url.path), fileSize > 16_000 else {
            let msg = fileSize == 0
                ? "Recording file missing — microphone may not have started."
                : "Recording too short — nothing was captured."
            whisperLogger.error("Recording file invalid: size=\(fileSize)")
            DebugLogStore.shared.log("Recording invalid: size=\(fileSize)", category: "Whisper", level: .error)
            transcriptionError = msg
            return
        }

        do {
            DebugLogStore.shared.log("Calling kit.transcribe()", category: "Whisper")
            let results = try await kit.transcribe(audioPath: url.path)
            let raw = results.map(\.text).joined(separator: " ")
            DebugLogStore.shared.log("Raw transcript (\(results.count) seg): \"\(raw.prefix(120))\"", category: "Whisper")
            let text = raw
                .replacing(#/\[[\w\s]+\]/#, with: "")  // strip Whisper hallucination tokens e.g. [BLANK_AUDIO]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            DebugLogStore.shared.log("Final transcript: \"\(text.prefix(80))\"", category: "Whisper")
            transcript = text
        } catch {
            whisperLogger.error("Transcription failed: \(error)")
            DebugLogStore.shared.log("Transcription error: \(error.localizedDescription)", category: "Whisper", level: .error)
            transcriptionError = "Transcription failed: \(error.localizedDescription)"
        }
    }

    // nonisolated: TCC/XPC callbacks fire on background threads.
    nonisolated private static func askMicrophonePermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioApplication.requestRecordPermission { cont.resume(returning: $0) }
        }
    }
}

// MARK: - SpeechServiceProtocol conformance

extension WhisperSpeechService: SpeechServiceProtocol {
    var isInterrupted: Bool { false }
    var isRecordingPublisher: AnyPublisher<Bool, Never> { $isRecording.eraseToAnyPublisher() }
    var isAuthorizedPublisher: AnyPublisher<Bool, Never> { $isAuthorized.eraseToAnyPublisher() }
    var transcriptPublisher: AnyPublisher<String, Never> { $transcript.eraseToAnyPublisher() }
    var isTranscribingPublisher: AnyPublisher<Bool, Never> { $isTranscribing.eraseToAnyPublisher() }
    var isInterruptedPublisher: AnyPublisher<Bool, Never> { Just(false).eraseToAnyPublisher() }
    var transcriptionErrorPublisher: AnyPublisher<String?, Never> { $transcriptionError.eraseToAnyPublisher() }
}
