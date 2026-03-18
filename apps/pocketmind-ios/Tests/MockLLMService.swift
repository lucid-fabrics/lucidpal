import Combine
import Foundation
@testable import PocketMind

@MainActor
final class MockLLMService: LLMServiceProtocol {
    var isLoaded: Bool = false
    var isLoading: Bool = false
    var isGenerating: Bool = false

    private let isLoadedSubject    = CurrentValueSubject<Bool, Never>(false)
    private let isLoadingSubject   = CurrentValueSubject<Bool, Never>(false)
    private let isGeneratingSubject = CurrentValueSubject<Bool, Never>(false)

    nonisolated var isLoadedPublisher: AnyPublisher<Bool, Never> {
        MainActor.assumeIsolated { isLoadedSubject.eraseToAnyPublisher() }
    }
    nonisolated var isLoadingPublisher: AnyPublisher<Bool, Never> {
        MainActor.assumeIsolated { isLoadingSubject.eraseToAnyPublisher() }
    }
    nonisolated var isGeneratingPublisher: AnyPublisher<Bool, Never> {
        MainActor.assumeIsolated { isGeneratingSubject.eraseToAnyPublisher() }
    }

    var stubbedTokens: [String] = []
    var shouldThrowOnGenerate: Error? = nil
    var loadedURL: URL? = nil
    var unloadCalled = false
    var cancelCalled = false

    func generate(systemPrompt: String, messages: [ChatMessage], thinkingEnabled: Bool) -> AsyncThrowingStream<String, Error> {
        let tokens = stubbedTokens
        let error = shouldThrowOnGenerate
        return AsyncThrowingStream { continuation in
            if let error {
                continuation.finish(throwing: error)
                return
            }
            for token in tokens { continuation.yield(token) }
            continuation.finish()
        }
    }

    func loadModel(at url: URL) async throws {
        loadedURL = url
        isLoaded = true
        isLoadedSubject.send(true)
    }

    func cancelGeneration() {
        cancelCalled = true
        isGenerating = false
    }

    func unloadModel() {
        unloadCalled = true
        isLoaded = false
        isLoadedSubject.send(false)
    }
}
