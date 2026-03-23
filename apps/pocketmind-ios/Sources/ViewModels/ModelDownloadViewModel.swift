import Combine
import Foundation
import OSLog

private let modelDownloadLogger = Logger(subsystem: "app.pocketmind", category: "ModelDownloadViewModel")

@MainActor
final class ModelDownloadViewModel: ObservableObject {
    @Published var selectedModel: ModelInfo
    @Published var availableModels: [ModelInfo]
    @Published private(set) var downloadState: DownloadState = .idle
    @Published private(set) var isModelLoaded = false
    @Published private(set) var isModelLoading = false
    @Published var loadError: String?
    @Published var deleteError: String?

    let downloader: any ModelDownloaderProtocol
    private let llmService: any LLMServiceProtocol
    let settings: any AppSettingsProtocol
    private var cancellables = Set<AnyCancellable>()

    init(
        llmService: any LLMServiceProtocol,
        settings: any AppSettingsProtocol,
        downloader: any ModelDownloaderProtocol
    ) {
        self.llmService = llmService
        self.settings = settings
        self.downloader = downloader

        let ram = settings.deviceRAMGB
        let models = ModelInfo.available(physicalRAMGB: ram)
        self.availableModels = models.isEmpty ? [.qwen3_5_2B] : models

        // Pre-select the device-recommended model when nothing has been downloaded yet.
        // If the user's saved model is already on disk, keep their choice.
        let savedModel = settings.selectedModel
        self.selectedModel = savedModel.isDownloaded
            ? savedModel
            : ModelInfo.recommended(physicalRAMGB: ram)
        self.isModelLoaded = llmService.isLoaded

        // assign(to: &$property) uses weak self internally — no retain cycle.
        downloader.statePublisher.assign(to: &$downloadState)
        llmService.isLoadedPublisher
            .sink { [weak self] in self?.isModelLoaded = $0 }
            .store(in: &cancellables)
        llmService.isLoadingPublisher
            .sink { [weak self] in self?.isModelLoading = $0 }
            .store(in: &cancellables)

        // Auto-load immediately when download finishes.
        downloader.statePublisher
            .compactMap { state -> URL? in
                if case .completed(let url) = state { return url }
                return nil
            }
            .sink { [weak self] _ in
                Task { [weak self] in await self?.loadModel() }
            }
            .store(in: &cancellables)

        // Auto-load the previously selected model on launch if already on disk.
        if settings.selectedModel.isDownloaded && !llmService.isLoaded {
            Task { [weak self] in await self?.loadModel() }
        }
    }

    /// Select a model. Cancels any in-flight download for the previous selection.
    func selectModel(_ model: ModelInfo) {
        guard model.id != selectedModel.id else { return }
        cancelDownload()
        selectedModel = model
    }

    func startDownload() {
        downloader.download(model: selectedModel)
    }

    func cancelDownload() {
        downloader.cancel()
    }

    func loadModel() async {
        guard selectedModel.isDownloaded else { return }
        loadError = nil
        do {
            let role: ModelType = selectedModel.isVisionModel ? .vision : .text
            try await llmService.loadModel(at: selectedModel.localURL, contextSize: UInt32(settings.contextSize), role: role)
            settings.selectedModelID = selectedModel.id
            downloader.resetState()
        } catch {
            modelDownloadLogger.error("loadModel failed: \(error)")
            loadError = error.localizedDescription
            downloader.resetState()
        }
    }

    func deleteModel(_ model: ModelInfo) {
        deleteError = nil
        if llmService.isLoaded && settings.selectedModelID == model.id {
            let role: ModelType = model.isVisionModel ? .vision : .text
            llmService.unloadModel(role: role)
        }
        do {
            try downloader.deleteModel(model)
        } catch {
            modelDownloadLogger.error("deleteModel failed: \(error)")
            deleteError = "Could not delete model: \(error.localizedDescription)"
        }
    }
}
