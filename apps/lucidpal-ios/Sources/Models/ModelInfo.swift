import Foundation

// MARK: - Model Capability

/// Describes what a model can do.
struct ModelCapability: OptionSet, Hashable, Sendable {
    let rawValue: Int

    static let text   = ModelCapability(rawValue: 1 << 0)  // Text inference
    static let vision = ModelCapability(rawValue: 1 << 1)  // Image understanding

    /// Integrated = handles both text and vision with a single model load.
    static let integrated: ModelCapability = [.text, .vision]
    /// Vision-only: cannot do text inference efficiently (e.g. dedicated vision projectors).
    static let visionOnly: ModelCapability = [.vision]
    /// Text-only: no vision support.
    static let textOnly: ModelCapability = [.text]
}

// MARK: - Model Info

struct ModelInfo: Identifiable, Hashable, Sendable {

    // MARK: - Properties

    let id: String
    let displayName: String
    let downloadURL: URL
    let filename: String
    let fileSizeGB: Double
    let minimumRAMGB: Int
    /// What this model can do.
    let capabilities: ModelCapability
    /// URL for the multimodal projector (mmproj) file — only for vision models.
    let mmprojURL: URL?
    /// Filename for the mmproj file on disk.
    let mmprojFilename: String?
    /// Expected SHA256 hex digest of the downloaded GGUF file.
    /// Sourced from HuggingFace LFS metadata (lfs.oid field).
    /// nil = no checksum enforcement (e.g. custom/sideloaded models).
    let sha256: String?

    var localURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent(filename)
    }

    /// Local URL for the mmproj file.
    var mmprojLocalURL: URL? {
        guard let mmprojFilename else { return nil }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent(mmprojFilename)
    }

    /// Whether the mmproj file is downloaded (true if no mmproj needed).
    var isMmprojDownloaded: Bool {
        guard let mmprojLocalURL else { return true }
        return FileManager.default.fileExists(atPath: mmprojLocalURL.path)
    }

    var isDownloaded: Bool {
        FileManager.default.fileExists(atPath: localURL.path)
    }

    /// True when this model can understand images.
    var supportsVision: Bool {
        capabilities.contains(.vision)
    }

    /// True when this model can handle text AND vision (no switching needed).
    var isIntegrated: Bool {
        capabilities == .integrated
    }

    // MARK: - Available Models

    static let qwen3_5_0B8 = ModelInfo(
        id: "qwen3.5-0.8b-q4km",
        displayName: "Qwen3.5 0.8B",
        downloadURL: knownURL("https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B-Q4_K_M.gguf"),
        filename: "Qwen3.5-0.8B-Q4_K_M.gguf",
        fileSizeGB: 0.51,
        minimumRAMGB: 2,
        capabilities: .textOnly,
        mmprojURL: nil,
        mmprojFilename: nil,
        sha256: "bd258782e35f7f458f8aced1adc053e6e92e89bc735ba3be89d38a06121dc517"
    )

    static let qwen3_5_2B = ModelInfo(
        id: "qwen3.5-2b-q4km",
        displayName: "Qwen3.5 2B",
        downloadURL: knownURL("https://huggingface.co/unsloth/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B-Q4_K_M.gguf"),
        filename: "Qwen3.5-2B-Q4_K_M.gguf",
        fileSizeGB: 1.2,
        minimumRAMGB: 3,
        capabilities: .textOnly,
        mmprojURL: nil,
        mmprojFilename: nil,
        sha256: "aaf42c8b7c3cab2bf3d69c355048d4a0ee9973d48f16c731c0520ee914699223"
    )

    static let qwen3_5_4B = ModelInfo(
        id: "qwen3.5-4b-q4km",
        displayName: "Qwen3.5 4B",
        downloadURL: knownURL("https://huggingface.co/unsloth/Qwen3.5-4B-GGUF/resolve/main/Qwen3.5-4B-Q4_K_M.gguf"),
        filename: "Qwen3.5-4B-Q4_K_M.gguf",
        fileSizeGB: 2.5,
        minimumRAMGB: 5,
        capabilities: .textOnly,
        mmprojURL: nil,
        mmprojFilename: nil,
        sha256: "00fe7986ff5f6b463e62455821146049db6f9313603938a70800d1fb69ef11a4"
    )

    /// Qwen3.5 Vision 4B — integrated model: handles both text AND vision.
    /// Requires the mmproj (vision projector) file for CLIP image encoding.
    static let qwen3_5_vision = ModelInfo(
        id: "qwen3.5-4b-vision-q4km",
        displayName: "Qwen3.5 Vision 4B",
        downloadURL: knownURL("https://huggingface.co/bjivanovich/Qwen3.5-4B-Vision-GGUF/resolve/main/Qwen3.5-4B.Q4_K_M.gguf"),
        filename: "Qwen3.5-4B.Q4_K_M.gguf",
        fileSizeGB: 2.5,
        minimumRAMGB: 5,
        capabilities: .integrated,
        mmprojURL: knownURL("https://huggingface.co/bjivanovich/Qwen3.5-4B-Vision-GGUF/resolve/main/Qwen3.5-4B.BF16-mmproj.gguf"),
        mmprojFilename: "Qwen3.5-4B.BF16-mmproj.gguf",
        sha256: "9e63c847c78bb282afbcce7b1c70fdb0eb0ecd752e3de1b8f96a49d745ef2069"
    )

    // MARK: - Filters

    /// All models that support text inference and fit in RAM.
    /// Excludes integrated models — those are vision-only selectable (selecting them as
    /// "text" model is redundant since they handle both; users pick them in Vision section).
    static func textModels(physicalRAMGB: Int) -> [ModelInfo] {
        [.qwen3_5_0B8, .qwen3_5_2B, .qwen3_5_4B]
            .filter { $0.capabilities == .text && $0.minimumRAMGB <= physicalRAMGB }
    }

    /// All models that support vision and fit in RAM.
    static func visionModels(physicalRAMGB: Int) -> [ModelInfo] {
        [.qwen3_5_vision]
            .filter { $0.minimumRAMGB <= physicalRAMGB }
    }

    /// All models that fit in RAM.
    static func available(physicalRAMGB: Int) -> [ModelInfo] {
        [.qwen3_5_0B8, .qwen3_5_2B, .qwen3_5_4B, .qwen3_5_vision]
            .filter { $0.minimumRAMGB <= physicalRAMGB }
    }

    static func recommended(physicalRAMGB: Int) -> ModelInfo {
        physicalRAMGB >= 5 ? .qwen3_5_4B : .qwen3_5_2B
    }

    // MARK: - Private Helpers

    private static func knownURL(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Invalid hardcoded URL: \(string)")
        }
        return url
    }
}
