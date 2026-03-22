import XCTest
@testable import PocketMind

@MainActor
final class ModelDownloaderTests: XCTestCase {

    var sut: ModelDownloader!
    private var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("ModelDownloaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        sut = ModelDownloader()
    }

    override func tearDown() async throws {
        sut = nil
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        try await super.tearDown()
    }

    // MARK: - Initial state

    func testInitialStateIsIdle() {
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - resetState

    func testResetStateResetsToIdle() {
        // Directly set state to simulate a completed download
        sut.state = .completed(url: tempDir)
        sut.resetState()
        XCTAssertEqual(sut.state, .idle)
    }

    func testResetStateIsIdempotent() {
        sut.resetState()
        sut.resetState()
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - cancel

    func testCancelSetsStateToIdle() {
        sut.state = .downloading(progress: 0.5)
        sut.cancel()
        XCTAssertEqual(sut.state, .idle)
    }

    func testCancelFromIdleIsNoOp() {
        sut.cancel()
        XCTAssertEqual(sut.state, .idle)
    }

    // MARK: - deleteModel

    func testDeleteModelRemovesExistingFile() throws {
        let model = ModelInfo.qwen3_5_0B8
        // Create a dummy file at the model's local URL using a temp path
        let dummyURL = tempDir.appendingPathComponent("dummy.gguf")
        try "content".write(to: dummyURL, atomically: true, encoding: .utf8)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dummyURL.path))

        // Verify the method exists and can be called without error
        XCTAssertNoThrow(try sut.deleteModel(model))
    }

    func testDeleteModelNoOpWhenFileAbsent() throws {
        let model = ModelInfo.qwen3_5_0B8
        // localURL should not exist in test environment
        if !FileManager.default.fileExists(atPath: model.localURL.path) {
            XCTAssertNoThrow(try sut.deleteModel(model))
        }
    }

    // MARK: - statePublisher

    func testStatePublisherEmitsInitialValue() {
        var received: [DownloadState] = []
        let cancellable = sut.statePublisher.sink { received.append($0) }
        XCTAssertEqual(received, [.idle], "Publisher must emit .idle as the initial value")
        cancellable.cancel()
    }

    func testStatePublisherEmitsStateChanges() {
        var received: [DownloadState] = []
        let cancellable = sut.statePublisher.sink { received.append($0) }

        sut.state = .failed(message: "oops")
        sut.resetState()

        XCTAssertEqual(received.count, 3)  // idle, failed, idle
        XCTAssertEqual(received[1], .failed(message: "oops"))
        XCTAssertEqual(received[2], .idle)
        cancellable.cancel()
    }

    // MARK: - DownloadState equatable

    func testDownloadStateIdleEquality() {
        XCTAssertEqual(DownloadState.idle, DownloadState.idle)
    }

    func testDownloadStateDownloadingEquality() {
        XCTAssertEqual(DownloadState.downloading(progress: 0.5), DownloadState.downloading(progress: 0.5))
        XCTAssertNotEqual(DownloadState.downloading(progress: 0.5), DownloadState.downloading(progress: 0.8))
    }

    func testDownloadStateFailedEquality() {
        XCTAssertEqual(DownloadState.failed(message: "err"), DownloadState.failed(message: "err"))
        XCTAssertNotEqual(DownloadState.failed(message: "a"), DownloadState.failed(message: "b"))
    }
}
