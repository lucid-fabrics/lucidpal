import Foundation
import UIKit

/// Error type for VisionImageProcessor operations.
enum VisionProcessorError: LocalizedError {
    case invalidImageData
    case resizeFailed
    case jpegEncodingFailed
    case base64EncodingFailed
    case thumbnailGenerationFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageData:    return "Could not read image data."
        case .resizeFailed:        return "Failed to resize image."
        case .jpegEncodingFailed:  return "Failed to encode image as JPEG."
        case .base64EncodingFailed: return "Failed to encode image as base64."
        case .thumbnailGenerationFailed: return "Failed to generate thumbnail."
        }
    }
}

/// Pre-processing pipeline for images before sending to the vision model.
/// Resizes to 896×896, JPEG 0.8 compresses, base64-encodes, and generates UI thumbnails.
struct VisionImageProcessor: Sendable {

    // MARK: - Constants

    /// Target edge length — Qwen3-VL expects 896×896 input.
    static let targetSize: CGFloat = 896
    /// JPEG compression quality (0.8 as per spec).
    static let jpegQuality: CGFloat = 0.8
    /// Thumbnail edge length for the chat UI strip.
    static let thumbnailSize: CGFloat = 80

    // MARK: - Public API

    /// Fully processes a UIImage: resizes, compresses, base64-encodes, and generates a thumbnail.
    /// Returns an AttachedImage ready to embed in a ChatMessage.
    func process(_ image: UIImage) async throws -> AttachedImage {
        guard let resized = resize(image, to: Self.targetSize) else {
            throw VisionProcessorError.resizeFailed
        }
        guard let jpeg = resized.jpegData(compressionQuality: Self.jpegQuality) else {
            throw VisionProcessorError.jpegEncodingFailed
        }
        guard let base64 = jpeg.base64EncodedString() as String? else {
            throw VisionProcessorError.base64EncodingFailed
        }
        let thumbnail = await generateThumbnail(from: resized)
        return AttachedImage(
            localURL: temporaryFileURL(),
            base64Data: base64,
            thumbnailData: thumbnail,
            width: Int(resized.size.width),
            height: Int(resized.size.height)
        )
    }

    /// Synchronous version for use in contexts where async is inconvenient.
    func processSync(_ image: UIImage) throws -> AttachedImage {
        guard let resized = resize(image, to: Self.targetSize) else {
            throw VisionProcessorError.resizeFailed
        }
        guard let jpeg = resized.jpegData(compressionQuality: Self.jpegQuality) else {
            throw VisionProcessorError.jpegEncodingFailed
        }
        guard let base64 = jpeg.base64EncodedString() as String? else {
            throw VisionProcessorError.base64EncodingFailed
        }
        let thumbnail = generateThumbnailSync(from: resized)
        return AttachedImage(
            localURL: temporaryFileURL(),
            base64Data: base64,
            thumbnailData: thumbnail,
            width: Int(resized.size.width),
            height: Int(resized.size.height)
        )
    }

    // MARK: - Resize

    /// Resizes image to fit within a square of `targetSize` edge length, preserving aspect ratio.
    /// The output is always exactly `targetSize × targetSize` by scaling the shorter edge
    /// to `targetSize` and centering the result on a transparent/solid-filled canvas.
    private func resize(_ image: UIImage, to targetSize: CGFloat) -> UIImage? {
        let size = image.size
        let scale: CGFloat = min(targetSize / size.width, targetSize / size.height)
        let scaledSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1  // Do not scale for device resolution — we want exact pixel dimensions
        format.opaque = true

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetSize, height: targetSize), format: format)

        return renderer.image { context in
            // Fill with white (or transparent if we were doing alpha — spec implies solid fill)
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: targetSize, height: targetSize)))
            // Center the scaled image
            let x = (targetSize - scaledSize.width) / 2
            let y = (targetSize - scaledSize.height) / 2
            image.draw(in: CGRect(origin: CGPoint(x: x, y: y), size: scaledSize))
        }
    }

    // MARK: - Thumbnail

    /// Async thumbnail generation — runs on a background thread automatically.
    private func generateThumbnail(from image: UIImage) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            self.generateThumbnailSync(from: image)
        }.value
    }

    /// Generates a low-resolution JPEG thumbnail for the chat UI strip.
    private func generateThumbnailSync(from image: UIImage) -> Data? {
        let thumbSize = CGSize(width: Self.thumbnailSize, height: Self.thumbnailSize)
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: thumbSize, format: format)
        let thumb = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: thumbSize))
        }
        return thumb.jpegData(compressionQuality: 0.6)
    }

    // MARK: - Helpers

    /// Returns a URL under the temporary directory for persisting the full image.
    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
    }
}
