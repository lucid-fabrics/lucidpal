import XCTest
@testable import PocketMind

@MainActor
final class ModelDownloadViewModelTests: XCTestCase {
    var mockLLM: MockLLMService!
    var settings: AppSettings!
    var viewModel: ModelDownloadViewModel!

    override func setUp() {
        super.setUp()
        mockLLM = MockLLMService()
        settings = AppSettings()
        viewModel = ModelDownloadViewModel(llmService: mockLLM, settings: settings)
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
}
