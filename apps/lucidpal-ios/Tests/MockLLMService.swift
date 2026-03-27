import Combine
import Foundation
@testable import LucidPal

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
    var isVisionModelLoaded: Bool = false

    private let isLoadedSubject     = CurrentValueSubject<Bool, Never>(false)
    private let isLoadingSubject    = CurrentValueSubject<Bool, Never>(false)
    private let isGeneratingSubject = CurrentValueSubject<Bool, Never>(false)

    var contextTruncatedPublisher: AnyPublisher<Void, Never> {
        Empty().eraseToAnyPublisher()
    }

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
    /// Tokens returned on the second `generate` call (e.g. post-search re-generation).
    var secondStubbedTokens: [String] = []
    var shouldThrowOnGenerate: Error? = nil
    var loadedURL: URL? = nil
    var unloadCalled = false
    var cancelCalled = false
    private(set) var generateCallCount = 0

    func generate(systemPrompt: String, messages: [ChatMessage], thinkingEnabled: Bool, modelRole: ModelType) -> AsyncThrowingStream<String, Error> {
        generateCallCount += 1
        let tokens = generateCallCount > 1 && !secondStubbedTokens.isEmpty ? secondStubbedTokens : stubbedTokens
        let error = shouldThrowOnGenerate
        let loaded = isLoaded
        return AsyncThrowingStream { continuation in
            if !loaded {
                continuation.finish(throwing: LLMError.modelNotLoaded)
                return
            }
            if let error {
                continuation.finish(throwing: error)
                return
            }
            for token in tokens { continuation.yield(token) }
            continuation.finish()
        }
    }

    func loadModel(at url: URL, contextSize: UInt32, role: ModelType, isIntegrated: Bool, mmprojURL: URL? = nil) async throws {
        loadedURL = url
        isLoaded = true  // didSet fires isLoadedSubject
    }

    func cancelGeneration() {
        cancelCalled = true
        isGenerating = false  // didSet fires isGeneratingSubject
    }

    func unloadModel(role: ModelType) {
        unloadCalled = true
        isLoaded = false  // didSet fires isLoadedSubject
    }

    func unload() {
        unloadCalled = true
        isLoaded = false
    }
}
