import XCTest
import UIKit
@testable import LucidPal

@MainActor
final class VisionImageProcessorTests: XCTestCase {

    private let processor = VisionImageProcessor()

    // MARK: - Constants

    func testMaxDimensionIs896() throws {
        // Access via reflection or test behavior — verify resize caps at 896
        let large = makeTestImage(size: CGSize(width: 2000, height: 1500))
        let resized = try XCTUnwrap(processor.resizePreservingAspect(image: large, maxDimension: 896))
        XCTAssertGreaterThan(resized.size.width, 0)
        XCTAssertGreaterThan(resized.size.height, 0)
        XCTAssertLessThanOrEqual(resized.size.width, 896)
        XCTAssertLessThanOrEqual(resized.size.height, 896)
    }

    // MARK: - resizePreservingAspect

    func testResizePreservingAspectLandscape() throws {
        let largeLandscape = makeTestImage(size: CGSize(width: 2000, height: 1000))
        let resized = try XCTUnwrap(processor.resizePreservingAspect(image: largeLandscape, maxDimension: 896))
        XCTAssertGreaterThan(resized.size.width, 0)
        XCTAssertGreaterThan(resized.size.height, 0)
        XCTAssertLessThanOrEqual(resized.size.width, 896)
        XCTAssertLessThanOrEqual(resized.size.height, 896)
        XCTAssertEqual(resized.size.width / resized.size.height, 2.0, accuracy: 0.01)
    }

    func testResizePreservingAspectPortrait() throws {
        let largePortrait = makeTestImage(size: CGSize(width: 1000, height: 2000))
        let resized = try XCTUnwrap(processor.resizePreservingAspect(image: largePortrait, maxDimension: 896))
        XCTAssertGreaterThan(resized.size.width, 0)
        XCTAssertGreaterThan(resized.size.height, 0)
        XCTAssertLessThanOrEqual(resized.size.width, 896)
        XCTAssertLessThanOrEqual(resized.size.height, 896)
        XCTAssertEqual(resized.size.height / resized.size.width, 2.0, accuracy: 0.01)
    }

    func testResizePreservingAspectSmallImage() throws {
        let small = makeTestImage(size: CGSize(width: 500, height: 300))
        let resized = try XCTUnwrap(processor.resizePreservingAspect(image: small, maxDimension: 896))
        XCTAssertEqual(resized.size.width, 500)
        XCTAssertEqual(resized.size.height, 300)
    }

    func testResizePreservingAspectSquare() throws {
        let square = makeTestImage(size: CGSize(width: 1000, height: 1000))
        let resized = try XCTUnwrap(processor.resizePreservingAspect(image: square, maxDimension: 896))
        XCTAssertEqual(resized.size.width, 896)
        XCTAssertEqual(resized.size.height, 896)
    }

    // MARK: - process

    func testProcessReturnsNonNilAttachedImage() throws {
        let image = makeTestImage(size: CGSize(width: 2000, height: 1500))
        let result = try processor.process(image)
        XCTAssertGreaterThan(result.width, 0)
        XCTAssertGreaterThan(result.height, 0)
        XCTAssertLessThanOrEqual(result.width, 896)
        XCTAssertLessThanOrEqual(result.height, 896)
        XCTAssertFalse(result.base64Data.isEmpty)
        let decoded = try XCTUnwrap(Data(base64Encoded: result.base64Data))
        XCTAssertGreaterThan(decoded.count, 0, "Decoded base64 data should not be empty")
        XCTAssertEqual(result.localURL.pathExtension, "jpg")
    }

    func testProcessSetsCorrectDimensions() throws {
        let image = makeTestImage(size: CGSize(width: 2000, height: 1500))
        let result = try processor.process(image)
        XCTAssertEqual(result.width, 896)
        XCTAssertEqual(result.height, 672)
    }

    func testProcessProducesNonEmptyBase64() throws {
        let image = makeTestImage(size: CGSize(width: 1000, height: 1000))
        let result = try processor.process(image)
        XCTAssertFalse(result.base64Data.isEmpty)
    }

    func testProcessProducesValidBase64() throws {
        let image = makeTestImage(size: CGSize(width: 800, height: 600))
        let result = try processor.process(image)
        let data = try XCTUnwrap(Data(base64Encoded: result.base64Data))
        XCTAssertGreaterThan(data.count, 0)
    }

    func testProcessBase64IsJPEG() throws {
        let image = makeTestImage(size: CGSize(width: 1200, height: 900))
        let result = try processor.process(image)
        let data = try XCTUnwrap(Data(base64Encoded: result.base64Data))
        // JPEG starts with FFD8FF
        XCTAssertGreaterThanOrEqual(data.count, 3)
        XCTAssertEqual(data[0], 0xFF)
        XCTAssertEqual(data[1], 0xD8)
        XCTAssertEqual(data[2], 0xFF)
    }

    func testProcessGeneratesThumbnail() throws {
        let image = makeTestImage(size: CGSize(width: 1200, height: 900))
        let result = try processor.process(image)
        let thumbData = try XCTUnwrap(result.thumbnailData)
        XCTAssertGreaterThan(thumbData.count, 0)
    }

    func testProcessThumbnailIsSmallerThanFullImage() throws {
        let image = makeTestImage(size: CGSize(width: 2000, height: 2000))
        let result = try processor.process(image)
        guard let thumbData = result.thumbnailData,
              let fullData = Data(base64Encoded: result.base64Data) else {
            XCTFail("Missing data"); return
        }
        XCTAssertLessThan(thumbData.count, fullData.count)
    }

    func testProcessThumbnailIsJPEG() throws {
        let image = makeTestImage(size: CGSize(width: 1000, height: 1000))
        let result = try processor.process(image)
        guard let thumbData = result.thumbnailData else {
            XCTFail("thumbnailData was nil"); return
        }
        let isJPEG = thumbData.count >= 3 &&
            thumbData[0] == 0xFF &&
            thumbData[1] == 0xD8 &&
            thumbData[2] == 0xFF
        XCTAssertTrue(isJPEG, "Thumbnail should be JPEG data")
    }

    func testProcessThumbnailDimensionCapped() throws {
        let image = makeTestImage(size: CGSize(width: 2000, height: 2000))
        let result = try processor.process(image)
        guard let thumbData = result.thumbnailData,
              let thumbImage = UIImage(data: thumbData) else {
            XCTFail("Missing thumbnail"); return
        }
        let maxThumbSide = max(thumbImage.size.width, thumbImage.size.height)
        XCTAssertLessThanOrEqual(maxThumbSide, 224)
    }

    func testProcessAssignsUniqueUUIDs() throws {
        let image = makeTestImage(size: CGSize(width: 500, height: 500))
        let result1 = try processor.process(image)
        let result2 = try processor.process(image)
        XCTAssertNotEqual(result1.id, result2.id)
    }

    func testProcessCreatesTemporaryLocalURL() throws {
        let image = makeTestImage(size: CGSize(width: 400, height: 400))
        let result = try processor.process(image)
        XCTAssertEqual(result.localURL.pathExtension, "jpg")
        XCTAssertTrue(result.localURL.path.contains("tmp") || result.localURL.path.contains("Temp"),
                      "localURL should be in a temporary directory")
    }

    // MARK: - processAsync

    func testProcessAsyncReturnsEquivalentResult() async throws {
        let image = makeTestImage(size: CGSize(width: 1600, height: 1200))
        let asyncResult = try await processor.processAsync(image)
        let syncResult = try processor.process(image)

        XCTAssertEqual(asyncResult.width, syncResult.width)
        XCTAssertEqual(asyncResult.height, syncResult.height)
        XCTAssertEqual(asyncResult.base64Data, syncResult.base64Data)
    }

    // MARK: - Edge cases

    func testProcessMinimalPixelImage() throws {
        let tiny = makeTestImage(size: CGSize(width: 1, height: 1))
        let result = try processor.process(tiny)
        XCTAssertEqual(result.width, 1)
        XCTAssertEqual(result.height, 1)
        XCTAssertFalse(result.base64Data.isEmpty)
    }

    func testResizePreservingAspectExactMaxDimension() throws {
        let exact = makeTestImage(size: CGSize(width: 896, height: 896))
        let resized = try XCTUnwrap(processor.resizePreservingAspect(image: exact, maxDimension: 896))
        XCTAssertEqual(resized.size.width, 896)
        XCTAssertEqual(resized.size.height, 896)
    }

    // MARK: - Helper

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
