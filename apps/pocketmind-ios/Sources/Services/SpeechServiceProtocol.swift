import Combine
import Foundation

/// Protocol abstraction for SpeechService — enables mocking in unit tests
/// and decouples ChatViewModel from AVFoundation/Speech concrete classes.
@MainActor
protocol SpeechServiceProtocol: AnyObject {
    var isRecording: Bool { get }
    var isAuthorized: Bool { get }
    var transcript: String { get }
    /// True while audio has been captured and the STT engine is processing it.
    /// False for streaming engines (SFSpeechRecognizer) that produce results live.
    var isTranscribing: Bool { get }
    var isInterrupted: Bool { get }

    /// Combine publishers — use these instead of `$property` when the
    /// consumer holds `any SpeechServiceProtocol` (existentials can't project `@Published`).
    var isRecordingPublisher: AnyPublisher<Bool, Never> { get }
    var isAuthorizedPublisher: AnyPublisher<Bool, Never> { get }
    var transcriptPublisher: AnyPublisher<String, Never> { get }
    var isTranscribingPublisher: AnyPublisher<Bool, Never> { get }
    var isInterruptedPublisher: AnyPublisher<Bool, Never> { get }

    func requestAuthorization() async
    func startRecording() throws
    func stopRecording()
}

extension SpeechService: SpeechServiceProtocol {
    // SFSpeechRecognizer produces results live — there is no post-capture processing phase.
    var isTranscribing: Bool { false }
    var isRecordingPublisher: AnyPublisher<Bool, Never> { $isRecording.eraseToAnyPublisher() }
    var isAuthorizedPublisher: AnyPublisher<Bool, Never> { $isAuthorized.eraseToAnyPublisher() }
    var transcriptPublisher: AnyPublisher<String, Never> { $transcript.eraseToAnyPublisher() }
    var isTranscribingPublisher: AnyPublisher<Bool, Never> { Just(false).eraseToAnyPublisher() }
    var isInterruptedPublisher: AnyPublisher<Bool, Never> { $isInterrupted.eraseToAnyPublisher() }
}
