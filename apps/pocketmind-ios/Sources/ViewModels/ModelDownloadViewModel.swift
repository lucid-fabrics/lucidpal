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

    /// Controls which models appear: .text for text-only, .vision for any vision-capable.
    /// Set by ModelDownloadView on appear to filter the shared viewModel instance.
    @Published var capabilityFilter: ModelCapability?

    init(
        llmService: any LLMServiceProtocol,
        settings: any AppSettingsProtocol,
        downloader: any ModelDownloaderProtocol
    ) {
        self.llmService = llmService
        self.settings = settings
        self.downloader = downloader

        // Pre-populate availableModels with no filter — will be re-filtered when capabilityFilter is set.
        let ram = settings.deviceRAMGB
        self.availableModels = ModelInfo.available(physicalRAMGB: ram)

        // Pre-select the user's saved text model, or fall back to recommended.
        let savedTextModel = settings.selectedTextModel
        self.selectedModel = savedTextModel.isDownloaded
            ? savedTextModel
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

        // Auto-load the previously selected text model on launch if already on disk.
        if settings.selectedTextModel.isDownloaded && !llmService.isLoaded {
            Task { [weak self] in await self?.loadModel() }
        }

        // Re-filter availableModels whenever capabilityFilter changes.
        $capabilityFilter
            .sink { [weak self] filter in
                self?.refreshAvailableModels(filter: filter)
            }
            .store(in: &cancellables)
    }

    /// Refreshes availableModels based on the current capabilityFilter.
    func refreshAvailableModels(filter: ModelCapability?) {
        let ram = settings.deviceRAMGB
        let allModels = ModelInfo.available(physicalRAMGB: ram)
        let filteredModels: [ModelInfo]
        if let filter = filter {
            if filter == .text {
                filteredModels = allModels.filter { $0.capabilities == .text }
            } else {
                filteredModels = allModels.filter { $0.capabilities.contains(.vision) }
            }
        } else {
            filteredModels = allModels
        }
        availableModels = filteredModels.isEmpty ? [.qwen3_5_2B] : filteredModels
    }

    /// Select a model for download. Cancels any in-flight download for the previous selection.
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

    /// Loads the selected model into the LLM service.
    func loadModel() async {
        guard selectedModel.isDownloaded else { return }
        loadError = nil
        do {
            // Integrated models and text models both load as .text; purely vision models load as .vision.
            let role: ModelType = selectedModel.supportsVision && !selectedModel.isIntegrated ? .vision : .text
            try await llmService.loadModel(at: selectedModel.localURL, contextSize: UInt32(settings.contextSize), role: role)
            // Update the appropriate saved model ID.
            if role == .text {
                settings.selectedTextModelID = selectedModel.id
            } else {
                settings.selectedVisionModelID = selectedModel.id
            }
            downloader.resetState()
        } catch {
            modelDownloadLogger.error("loadmodel failed: \(error)")
            loadError = error.localizedDescription
            downloader.resetState()
        }
    }

    /// Deletes a model from disk. Unloads it first if currently loaded.
    func deleteModel(_ model: ModelInfo) {
        deleteError = nil
        let isTextLoaded = settings.selectedTextModelID == model.id && llmService.isLoaded
        let isVisionLoaded = settings.selectedVisionModelID == model.id && llmService.isLoaded
        if isTextLoaded || isVisionLoaded {
            let role: ModelType = isVisionLoaded ? .vision : .text
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
