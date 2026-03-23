import UIKit

/// Error types for image preprocessing failures.
enum VisionImageProcessorError: LocalizedError {
    case imageDataConversionFailed
    case resizeFailed
    case thumbnailGenerationFailed

    var errorDescription: String? {
        switch self {
        case .imageDataConversionFailed:
            return "Failed to convert image to JPEG data."
        case .resizeFailed:
            return "Failed to resize image."
        case .thumbnailGenerationFailed:
            return "Failed to generate thumbnail."
        }
    }
}

/// Preprocesses UIImage attachments for the vision language model.
/// Handles resizing, JPEG compression, base64 encoding, and thumbnail generation.
@MainActor
struct VisionImageProcessor {

    /// Maximum dimension for the full-resolution image sent to the LLM (Qwen3.5-Vision preferred: 896 px).
    private static let maxDimension: CGFloat = 896
    /// JPEG compression quality for the full-resolution image.
    private static let jpegQuality: CGFloat = 0.8
    /// Maximum dimension for the thumbnail preview.
    private static let thumbnailDimension: CGFloat = 224
    /// JPEG compression quality for the thumbnail.
    private static let thumbnailQuality: CGFloat = 0.5

    /// Fully preprocesses a UIImage for the vision model.
    /// Returns an AttachedImage ready to embed in a ChatMessage.
    func process(_ image: UIImage) throws -> AttachedImage {
        // Resize to max 896×896 preserving aspect ratio
        guard let resized = resizePreservingAspect(image: image, maxDimension: Self.maxDimension) else {
            throw VisionImageProcessorError.resizeFailed
        }

        // Full-resolution JPEG base64
        guard let jpegData = resized.jpegData(compressionQuality: Self.jpegQuality) else {
            throw VisionImageProcessorError.imageDataConversionFailed
        }
        let base64Data = jpegData.base64EncodedString()

        // Thumbnail
        let thumbnailData: Data?
        if let thumbnail = resizePreservingAspect(image: image, maxDimension: Self.thumbnailDimension),
           let thumbJpeg = thumbnail.jpegData(compressionQuality: Self.thumbnailQuality) {
            thumbnailData = thumbJpeg
        } else {
            thumbnailData = nil
        }

        return AttachedImage(
            id: UUID(),
            localURL: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg"),
            thumbnailData: thumbnailData,
            base64Data: base64Data,
            width: Int(resized.size.width),
            height: Int(resized.size.height)
        )
    }

    /// Resizes an image preserving its aspect ratio so neither width nor height exceeds maxDimension.
    func resizePreservingAspect(image: UIImage, maxDimension: CGFloat) -> UIImage? {
        let size = image.size
        let maxSide = max(size.width, size.height)

        guard maxSide > maxDimension else { return image }

        let scale = maxDimension / maxSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1  // Use screen scale for actual pixels
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
