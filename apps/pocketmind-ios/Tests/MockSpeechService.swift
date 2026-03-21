import Combine
import Foundation
@testable import PocketMind

@MainActor
final class MockSpeechService: SpeechServiceProtocol {
    var isRecording: Bool = false
    var isAuthorized: Bool = true
    var transcript: String = ""
    var isTranscribing: Bool = false

    private let isRecordingSubject    = CurrentValueSubject<Bool, Never>(false)
    private let isAuthorizedSubject   = CurrentValueSubject<Bool, Never>(true)
    private let transcriptSubject     = CurrentValueSubject<String, Never>("")
    private let isTranscribingSubject = CurrentValueSubject<Bool, Never>(false)

    var isRecordingPublisher: AnyPublisher<Bool, Never> {
        isRecordingSubject.eraseToAnyPublisher()
    }
    var isAuthorizedPublisher: AnyPublisher<Bool, Never> {
        isAuthorizedSubject.eraseToAnyPublisher()
    }
    var transcriptPublisher: AnyPublisher<String, Never> {
        transcriptSubject.eraseToAnyPublisher()
    }
    var isTranscribingPublisher: AnyPublisher<Bool, Never> {
        isTranscribingSubject.eraseToAnyPublisher()
    }

    var authorizationRequested = false
    var startCalled = false
    var stopCalled = false
    var shouldThrowOnStart: Error? = nil

    func requestAuthorization() async {
        authorizationRequested = true
    }

    func startRecording() throws {
        if let error = shouldThrowOnStart { throw error }
        isRecording = true
        isRecordingSubject.send(true)
        startCalled = true
    }

    func stopRecording() {
        isRecording = false
        isRecordingSubject.send(false)
        stopCalled = true
    }

    /// Simulates a transcript update (call from tests to drive speech input).
    func simulateTranscript(_ text: String) {
        transcript = text
        transcriptSubject.send(text)
    }

    /// Simulates recording ending naturally (triggers auto-submit observer).
    func simulateRecordingEnded() {
        isRecording = false
        isRecordingSubject.send(false)
    }
}
