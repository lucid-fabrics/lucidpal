import Combine
import Foundation
@testable import PocketMind

@MainActor
final class MockLLMService: LLMServiceProtocol {
    var isLoaded: Bool = false {
        didSet { isLoadedSubject.send(isLoaded) }
    }
    var isLoading: Bool = false {
        didSet { isLoadingSubject.send(isLoading) }
    }
    // didSet keeps isGeneratingPublisher in sync so ChatViewModel's guard fires correctly.
    var isGenerating: Bool = false {
        didSet { isGeneratingSubject.send(isGenerating) }
    }

    private let isLoadedSubject     = CurrentValueSubject<Bool, Never>(false)
    private let isLoadingSubject    = CurrentValueSubject<Bool, Never>(false)
    private let isGeneratingSubject = CurrentValueSubject<Bool, Never>(false)

    var isLoadedPublisher: AnyPublisher<Bool, Never> {
        isLoadedSubject.eraseToAnyPublisher()
    }
    var isLoadingPublisher: AnyPublisher<Bool, Never> {
        isLoadingSubject.eraseToAnyPublisher()
    }
    var isGeneratingPublisher: AnyPublisher<Bool, Never> {
        isGeneratingSubject.eraseToAnyPublisher()
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
        isLoaded = true  // didSet fires isLoadedSubject
    }

    func cancelGeneration() {
        cancelCalled = true
        isGenerating = false  // didSet fires isGeneratingSubject
    }

    func unloadModel() {
        unloadCalled = true
        isLoaded = false  // didSet fires isLoadedSubject
    }
}
