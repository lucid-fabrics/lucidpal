import SwiftUI

struct ModelDownloadView: View {
    @ObservedObject var viewModel: ModelDownloadViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            Text("Choose a Model")
                .font(.title2.bold())

            modelPicker

            modelDetails

            actionButton

            if case .failed(let msg) = viewModel.downloadState {
                Text(msg)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding(24)
    }

    private var modelPicker: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.availableModels, id: \.id) { model in
                Button {
                    viewModel.selectModel(model)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(model.displayName)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.primary)
                            if model.isDownloaded {
                                Text("Downloaded")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            } else {
                                Text(String(format: "%.1f GB", model.fileSizeGB))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if viewModel.selectedModel.id == model.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.accentColor)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(viewModel.selectedModel.id == model.id
                                  ? Color.accentColor.opacity(0.1)
                                  : Color(.systemGray6))
                    )
                }
            }
        }
    }

    private var modelDetails: some View {
        Text("Recommended for your device: \(ModelInfo.recommended(physicalRAMGB: viewModel.settings.deviceRAMGB).displayName)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var actionButton: some View {
        switch viewModel.downloadState {
        case .idle:
            if viewModel.isModelLoaded && viewModel.settings.selectedModelID == viewModel.selectedModel.id {
                Label("Loaded", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline.weight(.medium))
            } else if viewModel.selectedModel.isDownloaded {
                Button {
                    Task { await viewModel.loadModel() }
                } label: {
                    if viewModel.isModelLoading {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("Loading…")
                        }
                    } else {
                        Text("Load Model")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isModelLoading)
            } else {
                Button("Download") {
                    viewModel.startDownload()
                }
                .buttonStyle(.borderedProminent)
            }

        case .downloading(let progress):
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Text(String(format: "Downloading… %.0f%%", progress * 100))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Cancel", role: .cancel) {
                    viewModel.cancelDownload()
                }
                .font(.caption)
            }

        case .completed:
            Button("Load Model") {
                Task { await viewModel.loadModel() }
            }
            .buttonStyle(.borderedProminent)

        case .failed:
            Button("Retry") {
                viewModel.startDownload()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
