@testable import PocketMind
import XCTest

/// Regression tests for context-window budget consistency in LLMConstants.
///
/// The original crash: `generationReserveTokens (512) != maxNewTokens (768)`.
/// On a 4 K-context device the truncation budget was 4096 - 512 = 3584 prompt tokens,
/// but the generation loop would try to produce up to 768 tokens, overflowing the
/// context window and causing llama_decode to assert-crash at token 4096.
///
/// These tests enforce that the constants remain self-consistent so the same
/// class of bug cannot silently re-appear.
@MainActor
final class LLMConstantsTests: XCTestCase {

    // MARK: - Context size sanity

    func testSmallContextSizeIsPositive() {
        XCTAssertGreaterThan(LLMConstants.smallContextSize, 0)
    }

    func testLargeContextSizeIsPositive() {
        XCTAssertGreaterThan(LLMConstants.largeContextSize, 0)
    }

    func testLargeContextSizeIsAtLeastAsLargeAsSmall() {
        XCTAssertGreaterThanOrEqual(LLMConstants.largeContextSize, LLMConstants.smallContextSize)
    }

    // MARK: - Generation budget fits inside every supported context window

    /// maxNewTokens must fit inside the small (4 K) context with at least 1 token
    /// of headroom for a prompt. This is the invariant that was violated in the
    /// original crash.
    func testMaxNewTokensFitsInsideSmallContext() {
        let budget = Int(LLMConstants.smallContextSize) - Int(LLMConstants.maxNewTokens)
        XCTAssertGreaterThan(budget, 0,
            "maxNewTokens (\(LLMConstants.maxNewTokens)) must leave room for at least 1 prompt token in the small context (\(LLMConstants.smallContextSize))")
    }

    func testMaxNewTokensFitsInsideLargeContext() {
        let budget = Int(LLMConstants.largeContextSize) - Int(LLMConstants.maxNewTokens)
        XCTAssertGreaterThan(budget, 0,
            "maxNewTokens (\(LLMConstants.maxNewTokens)) must leave room for at least 1 prompt token in the large context (\(LLMConstants.largeContextSize))")
    }

    // MARK: - Batch capacity

    func testBatchCapacityCoversAtLeastMaxNewTokens() {
        XCTAssertGreaterThanOrEqual(LLMConstants.batchCapacity, LLMConstants.maxNewTokens,
            "batchCapacity must be at least maxNewTokens so single-token decode steps never exceed the batch allocation")
    }

    /// Regression test for the n_batch assert crash.
    /// llama.cpp aborts with GGML_ASSERT(n_tokens_all <= cparams.n_batch) when the
    /// prefill batch is larger than n_batch. We set n_batch = n_ctx at context creation
    /// time, so batchCapacity must be at least as large as the larger context size to
    /// ensure the prefill of a full prompt never exceeds it.
    func testBatchCapacityCoversLargeContextSize() {
        // swiftlint:disable line_length
        XCTAssertGreaterThanOrEqual(Int(LLMConstants.batchCapacity), Int(LLMConstants.largeContextSize),
            "batchCapacity (\(LLMConstants.batchCapacity)) < largeContextSize (\(LLMConstants.largeContextSize)): prefill of a full prompt on a high-RAM device would exceed n_batch and abort")
        // swiftlint:enable line_length
    }

    // MARK: - Minimum prompt headroom

    /// Require at least 256 prompt tokens on the smallest device so a realistic
    /// system prompt always fits. Adjust this lower-bound if the model's minimum
    /// system prompt grows beyond it.
    func testSmallContextLeavesReasonablePromptHeadroom() {
        let headroom = Int(LLMConstants.smallContextSize) - Int(LLMConstants.maxNewTokens)
        XCTAssertGreaterThanOrEqual(headroom, 256,
            "Less than 256 prompt tokens available on the small-context device — system prompt may be truncated to nothing")
    }

    // MARK: - Thread count

    func testMaxThreadCountIsAtLeastOne() {
        XCTAssertGreaterThanOrEqual(LLMConstants.maxThreadCount, 1)
    }

    // MARK: - Sampler temperature

    func testSamplerTemperatureIsInValidRange() {
        XCTAssertGreaterThan(LLMConstants.samplerTemperature, 0,
            "Temperature must be > 0 (0 = greedy, handled separately by llama.cpp)")
        XCTAssertLessThanOrEqual(LLMConstants.samplerTemperature, 2.0,
            "Temperature above 2.0 produces near-random output")
    }
}
