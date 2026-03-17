import Foundation

struct ModelInfo: Identifiable, Hashable {
    let id: String
    let displayName: String
    let downloadURL: URL
    let filename: String
    let fileSizeGB: Double
    let minimumRAMGB: Int

    var localURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: localURL.path)
    }

    static let qwen3_1_7B = ModelInfo(
        id: "qwen3-1.7b-q8",
        displayName: "Qwen3 1.7B (Q8) · 1.8 GB",
        downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/resolve/main/qwen3-1.7b-q8_0.gguf")!,
        filename: "qwen3-1.7b-q8_0.gguf",
        fileSizeGB: 1.83,
        minimumRAMGB: 3
    )

    static let qwen3_4B = ModelInfo(
        id: "qwen3-4b-q4",
        displayName: "Qwen3 4B (Q4_K_M) · 2.5 GB",
        downloadURL: URL(string: "https://huggingface.co/Qwen/Qwen3-4B-GGUF/resolve/main/qwen3-4b-q4_k_m.gguf")!,
        filename: "qwen3-4b-q4_k_m.gguf",
        fileSizeGB: 2.5,
        minimumRAMGB: 5
    )

    /// Returns all models suitable for the device's physical RAM.
    static func available(physicalRAMGB: Int) -> [ModelInfo] {
        let all: [ModelInfo] = [.qwen3_1_7B, .qwen3_4B]
        return all.filter { $0.minimumRAMGB <= physicalRAMGB }
    }

    /// Recommended model based on device RAM.
    static func recommended(physicalRAMGB: Int) -> ModelInfo {
        physicalRAMGB >= 5 ? .qwen3_4B : .qwen3_1_7B
    }
}
