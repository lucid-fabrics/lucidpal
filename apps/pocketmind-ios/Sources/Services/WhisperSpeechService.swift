import AVFoundation
import Combine
import Foundation
import OSLog
@preconcurrency import WhisperKit

private let whisperLogger = Logger(subsystem: "app.pocketmind", category: "Whisper")

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

    private var whisperKit: WhisperKit?
    private var recorder: AVAudioRecorder?
    private var silenceTimer: Timer?
    // Prevents re-entry into stopRecording while transcription is in progress.
    @Published private(set) var isTranscribing = false

    private static let silenceTimeoutSeconds: TimeInterval = 30
    private static let whisperKitPollIntervalMilliseconds: Int64 = 100
    private static let recordingURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("pm_whisper_input.m4a")

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
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        // Record at 16 kHz mono AAC — matches Whisper's expected input rate.
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let rec = try AVAudioRecorder(url: Self.recordingURL, settings: settings)
            rec.record()
            recorder = rec
        } catch {
            do {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            } catch let deactivationError {
                whisperLogger.error("Failed to deactivate audio session after recording error: \(deactivationError)")
            }
            throw error
        }

        transcript = ""
        isRecording = true

        silenceTimer = Timer.scheduledTimer(
            withTimeInterval: Self.silenceTimeoutSeconds,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.stopRecording() }
        }
    }

    func stopRecording() {
        guard isRecording, !isTranscribing else { return }
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
        Task { [weak self] in await self?.transcribeAndFinish(Self.recordingURL) }
    }

    // MARK: - Private

    private func loadWhisperKit() async {
        do {
            whisperKit = try await WhisperKit(model: "openai_whisper-tiny")
            isAuthorized = true
            whisperLogger.info("WhisperKit ready")
        } catch {
            whisperLogger.error("WhisperKit init failed: \(error)")
        }
    }

    private func transcribeAndFinish(_ url: URL) async {
        defer {
            isRecording = false
            isTranscribing = false
        }
        // Wait up to 5 s for WhisperKit if it's still loading (e.g. very short recording).
        let deadline = Date.now.addingTimeInterval(5)
        while whisperKit == nil, Date.now < deadline {
            try? await Task.sleep(for: .milliseconds(Self.whisperKitPollIntervalMilliseconds))
        }
        guard let kit = whisperKit else {
            whisperLogger.error("WhisperKit not ready after timeout — dropping transcription")
            return
        }
        guard FileManager.default.fileExists(atPath: url.path) else {
            whisperLogger.error("Recording file not found: \(url.path)")
            return
        }
        do {
            let results = try await kit.transcribe(audioPath: url.path)
            transcript = (results ?? []).map(\.text).joined(separator: " ")
                .replacing(#/\[[\w\s]+\]/#, with: "")  // strip Whisper hallucination tokens e.g. [BLANK_AUDIO]
                .trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            whisperLogger.error("Transcription failed: \(error)")
        }
    }

    // nonisolated: TCC/XPC callbacks fire on background threads.
    nonisolated private static func askMicrophonePermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
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
}
