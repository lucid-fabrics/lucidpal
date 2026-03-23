import XCTest
@testable import PocketMind

@MainActor
final class VisionImageProcessorTests: XCTestCase {

    func testResizePreservingAspect() async {
        let processor = VisionImageProcessor()
        let largeLandscape = makeTestImage(size: CGSize(width: 2000, height: 1000))
        let resized = processor.resizePreservingAspect(image: largeLandscape, maxDimension: 896)
        XCTAssertNotNil(resized)
        XCTAssertLessThanOrEqual(resized!.size.width, 896)
        XCTAssertLessThanOrEqual(resized!.size.height, 896)
        XCTAssertEqual(resized!.size.width / resized!.size.height, 2.0, accuracy: 0.01)
    }

    func testResizePreservingAspectPortrait() async {
        let processor = VisionImageProcessor()
        let largePortrait = makeTestImage(size: CGSize(width: 1000, height: 2000))
        let resized = processor.resizePreservingAspect(image: largePortrait, maxDimension: 896)
        XCTAssertNotNil(resized)
        XCTAssertLessThanOrEqual(resized!.size.width, 896)
        XCTAssertLessThanOrEqual(resized!.size.height, 896)
        XCTAssertEqual(resized!.size.height / resized!.size.width, 2.0, accuracy: 0.01)
    }

    func testResizePreservingAspectSmallImage() async {
        let processor = VisionImageProcessor()
        let small = makeTestImage(size: CGSize(width: 500, height: 300))
        let resized = processor.resizePreservingAspect(image: small, maxDimension: 896)
        XCTAssertEqual(resized!.size.width, 500)
        XCTAssertEqual(resized!.size.height, 300)
    }

    func testProcessProducesValidJPEG() async throws {
        let processor = VisionImageProcessor()
        let image = makeTestImage(size: CGSize(width: 1200, height: 900))
        let result = try processor.process(image)

        XCTAssertFalse(result.base64Data.isEmpty)
        let jpegBytes = Data(base64Encoded: result.base64Data)
        XCTAssertNotNil(jpegBytes)
        XCTAssertEqual(result.width, 896)
        XCTAssertEqual(result.height, 672)
    }

    func testProcessThumbnailIsSmaller() async throws {
        let processor = VisionImageProcessor()
        let image = makeTestImage(size: CGSize(width: 2000, height: 2000))
        let result = try processor.process(image)

        XCTAssertNotNil(result.thumbnailData)
        if let thumbData = result.thumbnailData,
           let thumbImage = UIImage(data: thumbData) {
            let maxThumbSide = max(thumbImage.size.width, thumbImage.size.height)
            XCTAssertLessThanOrEqual(maxThumbSide, 224)
        }
    }

    // MARK: - Helper

    private func makeTestImage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }
}
