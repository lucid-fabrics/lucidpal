import XCTest
@testable import PocketMind

final class ModelInfoTests: XCTestCase {

    // MARK: - available()

    func testAvailableIncludesOnly1B7OnLowRAM() {
        let models = ModelInfo.available(physicalRAMGB: 3)
        XCTAssertTrue(models.contains(.qwen3_1B7))
        XCTAssertFalse(models.contains(.qwen3_4B))
    }

    func testAvailableIncludesBothModelsOnHighRAM() {
        let models = ModelInfo.available(physicalRAMGB: 8)
        XCTAssertTrue(models.contains(.qwen3_1B7))
        XCTAssertTrue(models.contains(.qwen3_4B))
    }

    func testAvailableReturnsEmptyForVeryLowRAM() {
        XCTAssertTrue(ModelInfo.available(physicalRAMGB: 1).isEmpty)
    }

    func testAvailableIncludesBothAtExactBoundary() {
        // 5 GB is the minimum for qwen3_4B
        let models = ModelInfo.available(physicalRAMGB: 5)
        XCTAssertTrue(models.contains(.qwen3_4B))
    }

    // MARK: - recommended()

    func testRecommendedReturns4BAt5GBOrMore() {
        XCTAssertEqual(ModelInfo.recommended(physicalRAMGB: 5), .qwen3_4B)
        XCTAssertEqual(ModelInfo.recommended(physicalRAMGB: 16), .qwen3_4B)
    }

    func testRecommendedReturns1B7Below5GB() {
        XCTAssertEqual(ModelInfo.recommended(physicalRAMGB: 4), .qwen3_1B7)
        XCTAssertEqual(ModelInfo.recommended(physicalRAMGB: 1), .qwen3_1B7)
    }

    // MARK: - localURL / isDownloaded

    func testLocalURLEndsWithFilename() {
        XCTAssertEqual(ModelInfo.qwen3_1B7.localURL.lastPathComponent, ModelInfo.qwen3_1B7.filename)
        XCTAssertEqual(ModelInfo.qwen3_4B.localURL.lastPathComponent, ModelInfo.qwen3_4B.filename)
    }

    func testIsDownloadedFalseInTestEnvironment() {
        // No model files exist on disk during unit tests
        XCTAssertFalse(ModelInfo.qwen3_1B7.isDownloaded)
        XCTAssertFalse(ModelInfo.qwen3_4B.isDownloaded)
    }

    // MARK: - Static properties

    func testModelIDsAreUnique() {
        XCTAssertNotEqual(ModelInfo.qwen3_1B7.id, ModelInfo.qwen3_4B.id)
    }

    func testDownloadURLsUseHTTPS() {
        XCTAssertEqual(ModelInfo.qwen3_1B7.downloadURL.scheme, "https")
        XCTAssertEqual(ModelInfo.qwen3_4B.downloadURL.scheme, "https")
    }

    func testFileSizesArePositive() {
        XCTAssertGreaterThan(ModelInfo.qwen3_1B7.fileSizeGB, 0)
        XCTAssertGreaterThan(ModelInfo.qwen3_4B.fileSizeGB, 0)
    }

    func testHashableConformance() {
        var set = Set<ModelInfo>()
        set.insert(.qwen3_1B7)
        set.insert(.qwen3_1B7)
        XCTAssertEqual(set.count, 1)
    }
}
