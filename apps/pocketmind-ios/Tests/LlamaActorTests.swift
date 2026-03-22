import XCTest
@testable import PocketMind

/// LlamaActor wraps llama.cpp C FFI. Full generate/load tests require a physical
/// ARM64 device with a GGUF model file present. These tests cover observable state
/// and configuration constants that are safe to verify without hardware.
@MainActor
final class LlamaActorTests: XCTestCase {

    // MARK: - Initial state

    func testInitialStateIsNotLoaded() async {
        let actor = LlamaActor()
        let loaded = await actor.isLoaded
        XCTAssertFalse(loaded, "LlamaActor must report isLoaded=false before a model is loaded")
    }

    // MARK: - LLMConstants correctness

    func testBatchCapacityCoversLargeContextSize() {
        XCTAssertGreaterThanOrEqual(
            Int(LLMConstants.batchCapacity),
            Int(LLMConstants.largeContextSize),
            "batchCapacity must be >= largeContextSize so full-prompt prefills never overflow the batch buffer"
        )
    }

    func testSmallContextSmallerThanLargeContext() {
        XCTAssertLessThan(LLMConstants.smallContextSize, LLMConstants.largeContextSize)
    }

    func testMaxThreadCountIsPositive() {
        XCTAssertGreaterThan(LLMConstants.maxThreadCount, 0)
    }

    func testMaxNewTokensIsPositive() {
        XCTAssertGreaterThan(LLMConstants.maxNewTokens, 0)
    }

    func testSamplerTemperatureIsInValidRange() {
        XCTAssertGreaterThan(LLMConstants.samplerTemperature, 0)
        XCTAssertLessThanOrEqual(LLMConstants.samplerTemperature, 2.0)
    }

    func testBytesPerGBIsCorrect() {
        XCTAssertEqual(LLMConstants.bytesPerGB, 1_073_741_824)
    }

    func testLargeContextRAMThresholdIsPositive() {
        XCTAssertGreaterThan(LLMConstants.largeContextRAMThresholdGB, 0)
    }
}
