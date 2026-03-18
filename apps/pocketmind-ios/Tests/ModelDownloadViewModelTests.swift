import XCTest
@testable import PocketMind

@MainActor
final class ModelDownloadViewModelTests: XCTestCase {
    var mockLLM: MockLLMService!
    var mockDownloader: MockModelDownloader!
    var settings: AppSettings!
    var viewModel: ModelDownloadViewModel!

    override func setUp() {
        super.setUp()
        mockLLM = MockLLMService()
        mockDownloader = MockModelDownloader()
        settings = AppSettings()
        viewModel = ModelDownloadViewModel(llmService: mockLLM, settings: settings, downloader: mockDownloader)
    }

    func testInitDownloadStateIsIdle() {
        XCTAssertEqual(viewModel.downloadState, .idle)
    }

    func testInitIsModelLoadedMatchesService() {
        XCTAssertFalse(viewModel.isModelLoaded)
        XCTAssertEqual(viewModel.isModelLoaded, mockLLM.isLoaded)
    }

    func testSelectDifferentModelUpdatesSelection() {
        let models = viewModel.availableModels
        guard let other = models.first(where: { $0.id != viewModel.selectedModel.id }) else { return }
        viewModel.selectModel(other)
        XCTAssertEqual(viewModel.selectedModel.id, other.id)
    }

    func testSelectSameModelIsNoOp() {
        let current = viewModel.selectedModel
        viewModel.selectModel(current)
        XCTAssertEqual(viewModel.selectedModel.id, current.id)
    }

    func testDeleteUnloadedModelDoesNotCallUnload() {
        let model = viewModel.selectedModel
        viewModel.deleteModel(model)
        XCTAssertFalse(mockLLM.unloadCalled)
    }

    func testDeleteLoadedModelCallsUnload() {
        let model = viewModel.selectedModel
        // Simulate the model being loaded in the service directly
        mockLLM.isLoaded = true
        settings.selectedModelID = model.id
        viewModel.deleteModel(model)
        XCTAssertTrue(mockLLM.unloadCalled)
    }

    func testAvailableModelsNotEmpty() {
        XCTAssertFalse(viewModel.availableModels.isEmpty)
    }

    func testCancelDownloadResetsStateToIdle() {
        viewModel.cancelDownload()
        XCTAssertEqual(viewModel.downloadState, .idle)
    }

    // MARK: - Download / cancel via mock

    func testStartDownloadCallsDownloader() {
        viewModel.startDownload()
        XCTAssertTrue(mockDownloader.downloadCalled)
    }

    func testCancelDownloadCallsDownloader() {
        viewModel.cancelDownload()
        XCTAssertTrue(mockDownloader.cancelCalled)
    }

    // MARK: - loadModel

    func testLoadModelDoesNothingWhenModelNotOnDisk() async {
        // selectedModel.isDownloaded is false in test env (no file on disk)
        await viewModel.loadModel()
        XCTAssertFalse(viewModel.isModelLoaded)
        XCTAssertNil(viewModel.loadError)
    }

    // MARK: - deleteModel

    func testDeleteModelCallsDownloaderDelete() {
        let model = viewModel.selectedModel
        viewModel.deleteModel(model)
        XCTAssertEqual(mockDownloader.deletedModels.first?.id, model.id)
    }

    func testDeleteModelSetsDeleteErrorOnFailure() throws {
        mockDownloader.shouldThrowOnDelete = true
        viewModel.deleteModel(viewModel.selectedModel)
        let err = try XCTUnwrap(viewModel.deleteError)
        XCTAssertTrue(err.hasPrefix("Could not delete model:"))
    }

    func testDeleteLoadedModelUnloadsLLM() {
        let model = viewModel.selectedModel
        mockLLM.isLoaded = true
        settings.selectedModelID = model.id
        viewModel.deleteModel(model)
        XCTAssertTrue(mockLLM.unloadCalled)
    }
}
