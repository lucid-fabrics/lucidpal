import Combine
import Foundation
@testable import PocketMind

@MainActor
final class MockModelDownloader: ModelDownloaderProtocol {
    private(set) var state: DownloadState = .idle

    private let stateSubject = CurrentValueSubject<DownloadState, Never>(.idle)

    nonisolated var statePublisher: AnyPublisher<DownloadState, Never> {
        MainActor.assumeIsolated { stateSubject.eraseToAnyPublisher() }
    }

    var downloadCalled = false
    var cancelCalled = false
    var resetCalled = false
    var deletedModels: [ModelInfo] = []
    var shouldThrowOnDelete = false

    func download(model: ModelInfo) {
        downloadCalled = true
        setState(.downloading(progress: 0))
    }

    func cancel() {
        cancelCalled = true
        setState(.idle)
    }

    func resetState() {
        resetCalled = true
        setState(.idle)
    }

    func deleteModel(_ model: ModelInfo) throws {
        if shouldThrowOnDelete { throw CocoaError(.fileNoSuchFile) }
        deletedModels.append(model)
    }

    /// Simulate a completed download from tests.
    func simulateCompleted(url: URL = URL(fileURLWithPath: "/tmp/model.gguf")) {
        setState(.completed(url: url))
    }

    func simulateFailed(message: String = "Network error") {
        setState(.failed(message: message))
    }

    private func setState(_ s: DownloadState) {
        state = s
        stateSubject.send(s)
    }
}
