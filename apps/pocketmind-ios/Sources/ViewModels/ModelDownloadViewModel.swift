import Foundation
import SwiftUI

@MainActor
final class ModelDownloadViewModel: ObservableObject {
    @Published var selectedModel: ModelInfo
    @Published var availableModels: [ModelInfo]

    let downloader: ModelDownloader
    let llmService: LLMService
    let settings: AppSettings

    init(llmService: LLMService, settings: AppSettings) {
        self.llmService = llmService
        self.settings = settings
        self.downloader = ModelDownloader()

        let ram = settings.deviceRAMGB
        let models = ModelInfo.available(physicalRAMGB: ram)
        self.availableModels = models.isEmpty ? [.qwen3_1_7B] : models
        self.selectedModel = settings.selectedModel
    }

    var downloadState: DownloadState { downloader.state }

    func startDownload() {
        downloader.download(model: selectedModel)
    }

    func cancelDownload() {
        downloader.cancel()
    }

    func loadModel() async {
        guard selectedModel.isDownloaded else { return }
        do {
            try await llmService.loadModel(at: selectedModel.localURL)
            settings.selectedModelID = selectedModel.id
        } catch {
            // propagate via LLMService published state if needed
        }
    }

    func deleteModel(_ model: ModelInfo) {
        try? downloader.deleteModel(model)
        if llmService.isLoaded { llmService.unloadModel() }
    }
}
