import SwiftUI

struct ModelDownloadView: View {
    @ObservedObject var viewModel: ModelDownloadViewModel

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 56))
                .foregroundStyle(.accent)

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
            ForEach(viewModel.availableModels) { model in
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
                                .foregroundStyle(.accent)
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
            if viewModel.selectedModel.isDownloaded {
                Button("Load Model") {
                    Task { await viewModel.loadModel() }
                }
                .buttonStyle(.borderedProminent)
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
