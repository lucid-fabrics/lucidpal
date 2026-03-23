import Foundation

struct ModelInfo: Identifiable, Hashable, Sendable {

    // MARK: - Properties

    let id: String
    let displayName: String
    let downloadURL: URL
    let filename: String
    let fileSizeGB: Double
    let minimumRAMGB: Int

    var localURL: URL {
        // documentDirectory is guaranteed in a sandboxed iOS app; fall back to tmp only as a
        // last resort so callers never receive nil and the app never crashes.
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent(filename)
    }

    var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: localURL.path)
    }

    /// True when this model has vision capability (filename contains "vision" or "Vision").
    var isVisionModel: Bool {
        filename.localizedCaseInsensitiveContains("vision")
    }

    // MARK: - Available Models

    static let qwen3_5_0B8 = ModelInfo(
        id: "qwen3.5-0.8b-q4km",
        displayName: "Qwen3.5 0.8B (Q4_K_M) · 0.51 GB",
        downloadURL: knownURL("https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_K_M.gguf"),
        filename: "Qwen3.5-0.8B-Q4_K_M.gguf",
        fileSizeGB: 0.51,
        minimumRAMGB: 2
    )

    static let qwen3_5_2B = ModelInfo(
        id: "qwen3.5-2b-q4km",
        displayName: "Qwen3.5 2B (Q4_K_M) · 1.2 GB",
        downloadURL: knownURL("https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf"),
        filename: "Qwen3.5-2B-Q4_K_M.gguf",
        fileSizeGB: 1.2,
        minimumRAMGB: 3
    )

    static let qwen3_5_4B = ModelInfo(
        id: "qwen3.5-4b-q4km",
        displayName: "Qwen3.5 4B (Q4_K_M) · 2.5 GB",
        downloadURL: knownURL("https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q4_K_M.gguf"),
        filename: "Qwen3.5-4B-Q4_K_M.gguf",
        fileSizeGB: 2.5,
        minimumRAMGB: 5
    )

    /// Qwen3.5 Vision 4B — requires Qwen3.5-4B.BF16-mmproj.gguf to be downloaded alongside this file.
    /// The mmproj file is available at:
    /// https://huggingface.co/bjivanovich/Qwen3.5-4B-Vision-GGUF/resolve/main/Qwen3.5-4B.BF16-mmproj.gguf
    static let qwen3_5_vision = ModelInfo(
        id: "qwen3.5-4b-vision-q4km",
        displayName: "Qwen3.5 Vision 4B (Q4_K_M) · ~2.5 GB",
        downloadURL: knownURL("https://huggingface.co/bjivanovich/Qwen3.5-4B-Vision-GGUF/resolve/main/Qwen3.5-4B.Q4_K_M.gguf"),
        filename: "Qwen3.5-4B.Q4_K_M.gguf",
        fileSizeGB: 2.5,
        minimumRAMGB: 5
    )

    static func available(physicalRAMGB: Int) -> [ModelInfo] {
        [.qwen3_5_0B8, .qwen3_5_2B, .qwen3_5_4B, .qwen3_5_vision].filter { $0.minimumRAMGB <= physicalRAMGB }
    }

    static func recommended(physicalRAMGB: Int) -> ModelInfo {
        physicalRAMGB >= 5 ? .qwen3_5_4B : .qwen3_5_2B
    }

    // MARK: - Private Helpers

    // Compile-time-constant URLs — preconditionFailure surfaces typos during development
    private static func knownURL(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Invalid hardcoded URL: \(string)")
        }
        return url
    }
}
