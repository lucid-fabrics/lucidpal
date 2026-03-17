import Combine
import Foundation

@MainActor
final class ModelDownloadViewModel: ObservableObject {
    @Published var selectedModel: ModelInfo
    @Published var availableModels: [ModelInfo]
    @Published private(set) var downloadState: DownloadState = .idle
    @Published private(set) var isModelLoaded = false
    @Published private(set) var isModelLoading = false
    @Published var loadError: String?
    @Published var deleteError: String?

    let downloader: ModelDownloader
    private let llmService: LLMService
    let settings: AppSettings

    init(llmService: LLMService, settings: AppSettings) {
        self.llmService = llmService
        self.settings = settings
        self.downloader = ModelDownloader()

        let ram = settings.deviceRAMGB
        let models = ModelInfo.available(physicalRAMGB: ram)
        self.availableModels = models.isEmpty ? [.qwen3_1B7] : models
        self.selectedModel = settings.selectedModel
        self.isModelLoaded = llmService.isLoaded

        // assign(to: &$property) uses weak self internally — no retain cycle.
        downloader.$state.assign(to: &$downloadState)
        llmService.$isLoaded.assign(to: &$isModelLoaded)
        llmService.$isLoading.assign(to: &$isModelLoading)

        // Auto-load the previously selected model on launch if already on disk.
        // Task is enqueued after init completes — self is fully initialized when body runs.
        if settings.selectedModel.isDownloaded && !llmService.isLoaded {
            Task { await self.loadModel() }
        }
    }

    /// Select a model. Cancels any in-flight download for the previous selection.
    func selectModel(_ model: ModelInfo) {
        guard model.id != selectedModel.id else { return }
        cancelDownload()  // Clear stale progress from the previous model
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
            try await llmService.loadModel(at: selectedModel.localURL)
            settings.selectedModelID = selectedModel.id
            downloader.resetState()  // Reset download state — clears stale "Load Model" button
        } catch {
            loadError = error.localizedDescription
            downloader.resetState()  // Reset download UI — don't leave it stuck in "Load Model" state
        }
    }

    func deleteModel(_ model: ModelInfo) {
        deleteError = nil
        if llmService.isLoaded && settings.selectedModelID == model.id {
            llmService.unloadModel()
        }
        do {
            try downloader.deleteModel(model)
        } catch {
            deleteError = "Could not delete model: \(error.localizedDescription)"
        }
    }
}
