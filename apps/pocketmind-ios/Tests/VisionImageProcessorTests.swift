import UIKit
import XCTest
@testable import PocketMind

@MainActor
final class VisionImageProcessorTests: XCTestCase {

    private let processor = VisionImageProcessor()

    // MARK: - Constants

    func testTargetSizeIs896() {
        XCTAssertEqual(VisionImageProcessor.targetSize, 896)
    }

    func testJpegQualityIs08() {
        XCTAssertEqual(VisionImageProcessor.jpegQuality, 0.8, accuracy: 0.001)
    }

    func testThumbnailSizeIs80() {
        XCTAssertEqual(VisionImageProcessor.thumbnailSize, 80)
    }

    // MARK: - processSync

    func testProcessSyncReturnsNonNilAttachedImage() {
        let image = makeTestImage(size: CGSize(width: 2000, height: 1500))
        let result = try? processor.processSync(image)
        XCTAssertNotNil(result)
    }

    func testProcessSyncSetsCorrectDimensions() {
        let image = makeTestImage(size: CGSize(width: 2000, height: 1500))
        let result = try? processor.processSync(image)
        XCTAssertEqual(result?.width, 896)
        XCTAssertEqual(result?.height, 896)
    }

    func testProcessSyncProducesNonEmptyBase64() {
        let image = makeTestImage(size: CGSize(width: 1000, height: 1000))
        let result = try? processor.processSync(image)
        XCTAssertFalse(result?.base64Data.isEmpty ?? true)
    }

    func testProcessSyncProducesValidBase64() {
        let image = makeTestImage(size: CGSize(width: 800, height: 600))
        let result = try? processor.processSync(image)
        guard let base64 = result?.base64Data else {
            XCTFail("base64Data was nil"); return
        }
        // Valid base64 should decode without error
        let data = Data(base64Encoded: base64)
        XCTAssertNotNil(data)
        XCTAssertFalse(data?.isEmpty ?? true)
    }

    func testProcessSyncGeneratesThumbnail() {
        let image = makeTestImage(size: CGSize(width: 1200, height: 900))
        let result = try? processor.processSync(image)
        XCTAssertNotNil(result?.thumbnailData)
        XCTAssertFalse(result?.thumbnailData?.isEmpty ?? true)
    }

    func testProcessSyncThumbnailIsJPEG() {
        let image = makeTestImage(size: CGSize(width: 1000, height: 1000))
        let result = try? processor.processSync(image)
        guard let thumbData = result?.thumbnailData else {
            XCTFail("thumbnailData was nil"); return
        }
        // JPEG starts with FFD8FF
        let isJPEG = thumbData.count >= 3 &&
            thumbData[0] == 0xFF &&
            thumbData[1] == 0xD8 &&
            thumbData[2] == 0xFF
        XCTAssertTrue(isJPEG, "Thumbnail should be JPEG data")
    }

    func testProcessSyncThumbnailIsSmallerThanFullImage() {
        let image = makeTestImage(size: CGSize(width: 2000, height: 2000))
        let result = try? processor.processSync(image)
        guard let thumbData = result?.thumbnailData,
              let fullData = Data(base64Encoded: result?.base64Data ?? "") else {
            XCTFail("Missing data"); return
        }
        XCTAssertLessThan(thumbData.count, fullData.count)
    }

    func testProcessSyncAssignsUUID() {
        let image = makeTestImage(size: CGSize(width: 500, height: 500))
        let result = try? processor.processSync(image)
        XCTAssertNotNil(result?.id)
    }

    func testProcessSyncCreatesTemporaryLocalURL() {
        let image = makeTestImage(size: CGSize(width: 400, height: 400))
        let result = try? processor.processSync(image)
        XCTAssertNotNil(result?.localURL)
        XCTAssertEqual(result?.localURL.pathExtension, "jpg")
    }

    // MARK: - process (async)

    func testProcessAsyncReturnsEquivalentResult() async throws {
        let image = makeTestImage(size: CGSize(width: 1600, height: 1200))
        let asyncResult = try await processor.process(image)
        let syncResult = try processor.processSync(image)

        XCTAssertEqual(asyncResult.width, syncResult.width)
        XCTAssertEqual(asyncResult.height, syncResult.height)
        XCTAssertEqual(asyncResult.base64Data, syncResult.base64Data)
    }

    // MARK: - Helpers

    private func makeTestImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
