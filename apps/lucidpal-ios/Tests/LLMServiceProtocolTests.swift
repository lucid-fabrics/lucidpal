import Combine
@testable import LucidPal
import XCTest

/// Tests the LLMServiceProtocol contract using MockLLMService.
@MainActor
final class LLMServiceProtocolTests: XCTestCase {
    var mock: MockLLMService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mock = MockLLMService()
        cancellables = []
    }

    func testInitialStateIsNotLoaded() {
        XCTAssertFalse(mock.isLoaded)
    }

    func testInitialStateIsNotGenerating() {
        XCTAssertFalse(mock.isGenerating)
    }

    func testIsLoadedPublisherEmitsCurrentValue() {
        var received = [Bool]()
        mock.isLoadedPublisher
            .sink { received.append($0) }
            .store(in: &cancellables)
        XCTAssertEqual(received, [false])
    }

    func testIsGeneratingPublisherEmitsCurrentValue() {
        var received = [Bool]()
        mock.isGeneratingPublisher
            .sink { received.append($0) }
            .store(in: &cancellables)
        XCTAssertEqual(received, [false])
    }

    func testCancelGenerationSetsCancelCalled() {
        mock.cancelGeneration()
        XCTAssertTrue(mock.cancelCalled)
    }

    func testGenerateWhenNotLoadedThrows() async throws {
        mock.isLoaded = false
        let stream = mock.generate(systemPrompt: "sys", messages: [], thinkingEnabled: true, modelRole: .text)
        var threwError = false
        do {
            for try await _ in stream { }
        } catch {
            threwError = true
        }
        XCTAssertTrue(threwError, "generate should throw when model is not loaded")
    }

    func testGenerateWhenLoadedYieldsTokens() async throws {
        mock.isLoaded = true
        mock.stubbedTokens = ["Hello", " world"]
        let stream = mock.generate(systemPrompt: "sys", messages: [], thinkingEnabled: true, modelRole: .text)
        var tokens: [String] = []
        for try await token in stream {
            tokens.append(token)
        }
        XCTAssertEqual(tokens, ["Hello", " world"])
    }
}
