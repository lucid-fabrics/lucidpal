import Combine
import Foundation

/// Protocol abstraction for SpeechService — enables mocking in unit tests
/// and decouples ChatViewModel from AVFoundation/Speech concrete classes.
@MainActor
protocol SpeechServiceProtocol: AnyObject {
    var isRecording: Bool { get }
    var isAuthorized: Bool { get }
    var transcript: String { get }

    /// Combine publishers — use these instead of `$property` when the
    /// consumer holds `any SpeechServiceProtocol` (existentials can't project `@Published`).
    var isRecordingPublisher: AnyPublisher<Bool, Never> { get }
    var isAuthorizedPublisher: AnyPublisher<Bool, Never> { get }
    var transcriptPublisher: AnyPublisher<String, Never> { get }

    func requestAuthorization() async
    func startRecording() throws
    func stopRecording()
}

extension SpeechService: SpeechServiceProtocol {
    nonisolated var isRecordingPublisher: AnyPublisher<Bool, Never> {
        MainActor.assumeIsolated { $isRecording.eraseToAnyPublisher() }
    }
    nonisolated var isAuthorizedPublisher: AnyPublisher<Bool, Never> {
        MainActor.assumeIsolated { $isAuthorized.eraseToAnyPublisher() }
    }
    nonisolated var transcriptPublisher: AnyPublisher<String, Never> {
        MainActor.assumeIsolated { $transcript.eraseToAnyPublisher() }
    }
}
