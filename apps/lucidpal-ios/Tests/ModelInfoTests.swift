@testable import LucidPal
import XCTest

@MainActor
final class ModelInfoTests: XCTestCase {

    // MARK: - available()

    func testAvailableIncludesOnly0B8And2BOnLowRAM() {
        let models = ModelInfo.available(physicalRAMGB: 3)
        XCTAssertTrue(models.contains(.qwen3_5_0B8))
        XCTAssertTrue(models.contains(.qwen3_5_2B))
        XCTAssertFalse(models.contains(.qwen3_5_4B))
    }

    func testAvailableIncludesAllModelsOnHighRAM() {
        let models = ModelInfo.available(physicalRAMGB: 8)
        XCTAssertTrue(models.contains(.qwen3_5_0B8))
        XCTAssertTrue(models.contains(.qwen3_5_2B))
        XCTAssertTrue(models.contains(.qwen3_5_4B))
    }

    func testAvailableReturnsEmptyForVeryLowRAM() {
        XCTAssertTrue(ModelInfo.available(physicalRAMGB: 1).isEmpty)
    }

    func testAvailableIncludesAll3AtExactBoundary() {
        // 5 GB is the minimum for qwen3_5_4B
        let models = ModelInfo.available(physicalRAMGB: 5)
        XCTAssertTrue(models.contains(.qwen3_5_4B))
    }

    // MARK: - recommended()

    func testRecommendedReturns4BAt5GBOrMore() {
        XCTAssertEqual(ModelInfo.recommended(physicalRAMGB: 5), .qwen3_5_4B)
        XCTAssertEqual(ModelInfo.recommended(physicalRAMGB: 16), .qwen3_5_4B)
    }

    func testRecommendedReturns2BBelow5GB() {
        XCTAssertEqual(ModelInfo.recommended(physicalRAMGB: 4), .qwen3_5_2B)
        XCTAssertEqual(ModelInfo.recommended(physicalRAMGB: 1), .qwen3_5_2B)
    }

    // MARK: - localURL / isDownloaded

    func testLocalURLEndsWithFilename() {
        XCTAssertEqual(ModelInfo.qwen3_5_2B.localURL.lastPathComponent, ModelInfo.qwen3_5_2B.filename)
        XCTAssertEqual(ModelInfo.qwen3_5_4B.localURL.lastPathComponent, ModelInfo.qwen3_5_4B.filename)
    }

    func testIsDownloadedFalseInTestEnvironment() {
        // No model files exist on disk during unit tests
        XCTAssertFalse(ModelInfo.qwen3_5_2B.isDownloaded)
        XCTAssertFalse(ModelInfo.qwen3_5_4B.isDownloaded)
    }

    // MARK: - Static properties

    func testModelIDsAreUnique() {
        XCTAssertNotEqual(ModelInfo.qwen3_5_0B8.id, ModelInfo.qwen3_5_2B.id)
        XCTAssertNotEqual(ModelInfo.qwen3_5_2B.id, ModelInfo.qwen3_5_4B.id)
    }

    func testDownloadURLsUseHTTPS() {
        XCTAssertEqual(ModelInfo.qwen3_5_0B8.downloadURL.scheme, "https")
        XCTAssertEqual(ModelInfo.qwen3_5_2B.downloadURL.scheme, "https")
        XCTAssertEqual(ModelInfo.qwen3_5_4B.downloadURL.scheme, "https")
    }

    func testFileSizesArePositive() {
        XCTAssertGreaterThan(ModelInfo.qwen3_5_0B8.fileSizeGB, 0)
        XCTAssertGreaterThan(ModelInfo.qwen3_5_2B.fileSizeGB, 0)
        XCTAssertGreaterThan(ModelInfo.qwen3_5_4B.fileSizeGB, 0)
    }

    func testHashableConformance() {
        var set = Set<ModelInfo>()
        set.insert(.qwen3_5_2B)
        set.insert(.qwen3_5_2B)
        XCTAssertEqual(set.count, 1)
    }
}
