import XCTest
@testable import PocketMind

/// WhisperSpeechService uses AVAudioRecorder + WhisperKit (on-device C FFI).
/// Full recording/transcription tests require microphone permissions and a loaded
/// Whisper model on a physical device. These tests cover observable published state.
@MainActor
final class WhisperSpeechServiceTests: XCTestCase {

    var sut: WhisperSpeechService!

    override func setUp() async throws {
        try await super.setUp()
        sut = WhisperSpeechService()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initial state

    func testInitialIsRecordingIsFalse() {
        XCTAssertFalse(sut.isRecording)
    }

    func testInitialIsAuthorizedIsFalse() {
        XCTAssertFalse(sut.isAuthorized)
    }

    func testInitialTranscriptIsEmpty() {
        XCTAssertTrue(sut.transcript.isEmpty)
    }

    func testInitialIsTranscribingIsFalse() {
        XCTAssertFalse(sut.isTranscribing)
    }

    // MARK: - State machine guards

    func testStopRecordingWhenNotRecordingIsNoOp() {
        sut.stopRecording()
        XCTAssertFalse(sut.isRecording)
        XCTAssertFalse(sut.isTranscribing)
    }

    func testStartRecordingWhenUnauthorizedIsNoOp() throws {
        // isAuthorized=false — startRecording must bail out without crashing
        XCTAssertNoThrow(try sut.startRecording())
        XCTAssertFalse(sut.isRecording)
    }

    func testStopRecordingIsIdempotent() {
        sut.stopRecording()
        sut.stopRecording()
        XCTAssertFalse(sut.isRecording)
    }

    // MARK: - Protocol conformance

    func testConformsToSpeechServiceProtocol() {
        XCTAssertTrue(sut is any SpeechServiceProtocol)
    }
}
