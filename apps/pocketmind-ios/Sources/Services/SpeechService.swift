import AVFoundation
import Foundation
import OSLog
import Speech

private let speechLogger = Logger(subsystem: "com.pocketmind", category: "SpeechService")

@MainActor
final class SpeechService {
    @Published private(set) var isRecording = false
    @Published private(set) var isAuthorized = false
    @Published private(set) var transcript = ""

    private var recognizer: SFSpeechRecognizer?
    private var audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var silenceTimer: Timer?

    private static let silenceTimeoutSeconds: TimeInterval = 30
    private static let audioBufferSize: AVAudioFrameCount = 1024

    func requestAuthorization() async {
        let micGranted = await Self.askMicrophonePermission()
        guard micGranted else { return }

        let speechStatus = await Self.askSpeechPermission()
        guard speechStatus == .authorized else { return }

        recognizer = SFSpeechRecognizer()
        isAuthorized = recognizer?.isAvailable == true
    }

    // nonisolated: closures defined here are NOT @MainActor-isolated.
    // The TCC/XPC callbacks fire on background threads — if the closure carries @MainActor
    // isolation the Swift 6 runtime thunk asserts the wrong queue and crashes (EXC_BREAKPOINT).
    // Keeping these nonisolated lets CheckedContinuation.resume() be called from any thread.

    nonisolated private static func askMicrophonePermission() async -> Bool {
        await withCheckedContinuation { cont in
            AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
        }
    }

    nonisolated private static func askSpeechPermission() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
    }

    func startRecording() throws {
        guard isAuthorized, let recognizer, !isRecording else { return }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let req = SFSpeechAudioBufferRecognitionRequest()
            req.shouldReportPartialResults = true
            req.requiresOnDeviceRecognition = true
            request = req

            let node = audioEngine.inputNode
            node.installTap(onBus: 0, bufferSize: Self.audioBufferSize, format: node.outputFormat(forBus: 0)) { [weak self] buf, _ in
                self?.request?.append(buf)
            }

            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            // Clean up any partial state so the session doesn't stay locked in .record mode
            audioEngine.inputNode.removeTap(onBus: 0)
            request = nil
            do {
                try session.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                speechLogger.error("Failed to deactivate audio session during error cleanup: \(error)")
            }
            throw error
        }

        transcript = ""
        isRecording = true

        // Safety net: if isFinal never fires (e.g. silence, locale unsupported), auto-stop.
        silenceTimer = Timer.scheduledTimer(withTimeInterval: Self.silenceTimeoutSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.stopRecording() }
        }

        guard let request else { return }
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard self != nil else { return }
            if let result {
                Task { @MainActor [weak self] in
                    self?.transcript = result.bestTranscription.formattedString
                }
            }
            if error != nil || result?.isFinal == true {
                Task { @MainActor [weak self] in self?.stopRecording() }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        silenceTimer?.invalidate()
        silenceTimer = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        task?.finish()
        task = nil
        isRecording = false
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            speechLogger.error("Failed to deactivate audio session: \(error)")
        }
    }
}
