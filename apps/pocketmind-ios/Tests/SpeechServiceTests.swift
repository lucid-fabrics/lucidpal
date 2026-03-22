import XCTest
@testable import PocketMind

/// SpeechService uses AVAudioEngine + SFSpeechRecognizer, both requiring microphone
/// permissions and physical hardware. Full recording tests must run on a physical device.
/// These tests cover the observable published state that is safe to verify without hardware.
@MainActor
final class SpeechServiceTests: XCTestCase {

    var sut: SpeechService!

    override func setUp() async throws {
        try await super.setUp()
        sut = SpeechService()
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

    func testInitialIsInterruptedIsFalse() {
        XCTAssertFalse(sut.isInterrupted)
    }

    // MARK: - State machine guards

    func testStopRecordingWhenNotRecordingIsNoOp() {
        sut.stopRecording()
        XCTAssertFalse(sut.isRecording)
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
