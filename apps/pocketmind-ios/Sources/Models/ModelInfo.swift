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

    // MARK: - Available Models

    static let qwen3_1B7 = ModelInfo(
        id: "qwen3-1.7b-q8",
        displayName: "Qwen3 1.7B (Q8_0) · 1.83 GB",
        downloadURL: knownURL("https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q8_0.gguf"),
        filename: "Qwen3-1.7B-Q8_0.gguf",
        fileSizeGB: 1.83,
        minimumRAMGB: 3
    )

    static let qwen3_4B = ModelInfo(
        id: "qwen3-4b-q4",
        displayName: "Qwen3 4B (Q4_K_M) · 2.5 GB",
        downloadURL: knownURL("https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/Qwen3-4B-Q4_K_M.gguf"),
        filename: "Qwen3-4B-Q4_K_M.gguf",
        fileSizeGB: 2.5,
        minimumRAMGB: 5
    )

    static func available(physicalRAMGB: Int) -> [ModelInfo] {
        [.qwen3_1B7, .qwen3_4B].filter { $0.minimumRAMGB <= physicalRAMGB }
    }

    static func recommended(physicalRAMGB: Int) -> ModelInfo {
        physicalRAMGB >= 5 ? .qwen3_4B : .qwen3_1B7
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
