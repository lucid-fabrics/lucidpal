import Combine
import Foundation

@MainActor
final class ModelDownloadViewModel: ObservableObject {
    @Published var selectedModel: ModelInfo
    @Published var availableModels: [ModelInfo]
    @Published private(set) var downloadState: DownloadState = .idle
    @Published private(set) var isModelLoaded = false
    @Published var loadError: String?
    @Published var deleteError: String?

    let downloader: ModelDownloader
    private let llmService: LLMService
    let settings: AppSettings
    private var cancellables = Set<AnyCancellable>()

    init(llmService: LLMService, settings: AppSettings) {
        self.llmService = llmService
        self.settings = settings
        self.downloader = ModelDownloader()

        let ram = settings.deviceRAMGB
        let models = ModelInfo.available(physicalRAMGB: ram)
        self.availableModels = models.isEmpty ? [.qwen3_1_7B] : models
        self.selectedModel = settings.selectedModel
        self.isModelLoaded = llmService.isLoaded

        // Bridge downloader state into this ViewModel so views update correctly
        downloader.$state
            .receive(on: RunLoop.main)
            .assign(to: \.downloadState, on: self)
            .store(in: &cancellables)

        // Mirror LLMService load state so views never observe the service directly
        llmService.$isLoaded
            .receive(on: RunLoop.main)
            .assign(to: \.isModelLoaded, on: self)
            .store(in: &cancellables)

        // Auto-load the previously selected model on first launch if already downloaded
        if settings.selectedModel.isDownloaded && !llmService.isLoaded {
            Task { await self.loadModel() }
        }
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
        } catch {
            loadError = error.localizedDescription
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
