import Combine
import Foundation

/// Protocol abstraction for LLMService — enables mocking in unit tests
/// and decouples ViewModels from the llama.cpp concrete implementation.
@MainActor
protocol LLMServiceProtocol: AnyObject {
    var isLoaded: Bool { get }
    var isLoading: Bool { get }
    var isGenerating: Bool { get }
    var isVisionModelLoaded: Bool { get }

    /// Combine publishers — use these instead of `$property` when the
    /// consumer holds `any LLMServiceProtocol` (existentials can't project `@Published`).
    var isLoadedPublisher: AnyPublisher<Bool, Never> { get }
    var isLoadingPublisher: AnyPublisher<Bool, Never> { get }
    var isGeneratingPublisher: AnyPublisher<Bool, Never> { get }

    /// Generates a response using the specified model role.
    func generate(systemPrompt: String, messages: [ChatMessage], thinkingEnabled: Bool, modelRole: ModelType) -> AsyncThrowingStream<String, Error>

    /// Loads the model at the given URL for the specified role.
    func loadModel(at url: URL, contextSize: UInt32, role: ModelType, isIntegrated: Bool, mmprojURL: URL?) async throws

    /// Unloads the model for the specified role.
    func unloadModel(role: ModelType)

    func cancelGeneration()
    func unload()
}

extension LLMService {
    var isLoadedPublisher: AnyPublisher<Bool, Never> {
        $isLoaded.eraseToAnyPublisher()
    }
    var isLoadingPublisher: AnyPublisher<Bool, Never> {
        $isLoading.eraseToAnyPublisher()
    }
    var isGeneratingPublisher: AnyPublisher<Bool, Never> {
        $isGenerating.eraseToAnyPublisher()
    }
}
