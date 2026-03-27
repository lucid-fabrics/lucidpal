import Darwin
import Foundation
import OSLog

private let warmerLogger = Logger(subsystem: "app.lucidpal", category: "ModelPageCacheWarmer")

/// Hints the kernel page cache to prefetch model file bytes via F_RDADVISE before
/// llama.cpp memory-maps the file. Reduces demand-paging stalls on first inference.
enum ModelPageCacheWarmer {
    /// Maximum bytes to hint — 128 MB covers model headers and first layers without
    /// issuing an excessively large kernel advisory on small files.
    private static let maxHintBytes = 128 * 1_048_576

    /// Hints the first `byteCount` bytes of `url` into the kernel page cache.
    /// Uses fcntl(F_RDADVISE) — the iOS-native advisory read hint.
    /// Safe to call from any thread; no-op if the file doesn't exist or hint fails.
    static func hint(fileURL: URL, byteCount: Int = 64 * 1_048_576) {
        guard byteCount > 0 else { return }
        let clamped = min(byteCount, maxHintBytes)

        // Sandbox check: resolve symlinks on both sides so that a symlink inside
        // Documents pointing outside the sandbox cannot bypass the prefix check.
        // Also append "/" so a dir named "DocumentsEvil" doesn't pass the prefix.
        let resolvedDocuments = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .resolvingSymlinksInPath()
        // Resolve symlinks once and reuse — avoids TOCTOU if symlink targets shift.
        let resolvedFile = fileURL.resolvingSymlinksInPath()
        // Use pathComponents for containment check: avoids false positives from
        // unicode normalization differences and the "DocumentsEvil" prefix trap.
        guard let resolvedDocuments,
              resolvedFile.pathComponents.starts(with: resolvedDocuments.pathComponents),
              resolvedFile.pathComponents.count > resolvedDocuments.pathComponents.count else { return }

        let resolvedPath = resolvedFile.path(percentEncoded: false)
        let fd = open(resolvedPath, O_RDONLY)
        guard fd >= 0 else { return }
        defer { close(fd) }
        // Int32(clamping:) is safe even if clamped somehow exceeds Int32.max.
        var ra = radvisory(ra_offset: 0, ra_count: Int32(clamping: clamped))
        let result = fcntl(fd, F_RDADVISE, &ra)
        if result != 0 {
            warmerLogger.debug("F_RDADVISE failed for \(resolvedPath, privacy: .private): errno \(errno)")
        }
    }
}
