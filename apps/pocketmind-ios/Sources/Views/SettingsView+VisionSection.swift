import SwiftUI

// MARK: - Vision & Model Sections

extension SettingsView {
    var visionSection: some View {
        Section {
            Toggle(isOn: $viewModel.visionEnabled) {
                Label("Vision", systemImage: "camera.viewfinder")
            }
        } footer: {
            Text("When enabled, photo attachments are processed by the vision model. Disable to only use text inference.")
        }
    }

    var textModelSection: some View {
        Section {
            ForEach(viewModel.availableTextModels, id: \.id) { model in
                modelRow(
                    model: model,
                    isSelected: viewModel.selectedTextModelID == model.id,
                    isLoaded: viewModel.selectedTextModelID == model.id && downloadViewModel.isModelLoaded,
                    onSelect: {
                        if model.isDownloaded {
                            viewModel.selectTextModel(model)
                            downloadViewModel.selectModel(model)
                            Task { await downloadViewModel.loadModel() }
                        } else {
                            downloadViewModel.selectModel(model)
                        }
                    }
                )
            }

            NavigationLink("Download More Models") {
                ModelDownloadView(viewModel: downloadViewModel, capabilityFilter: .text)
            }
        } header: {
            Text("Text Model")
        } footer: {
            Text("Device RAM: \(viewModel.deviceRAMGB) GB · Free storage: \(viewModel.availableStorageGB.map { String(format: "%.1f GB free", $0) } ?? "Unknown")")
        }
    }

    var visionModelSection: some View {
        Section {
            if viewModel.availableVisionModels.isEmpty {
                Text("No vision models available for your device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.availableVisionModels, id: \.id) { model in
                    modelRow(
                        model: model,
                        isSelected: viewModel.selectedVisionModelID == model.id || model.isIntegrated && viewModel.selectedTextModelID == model.id,
                        isLoaded: false,
                        onSelect: {
                            if model.isDownloaded {
                                viewModel.selectVisionModel(model)
                                if model.isIntegrated {
                                    viewModel.selectTextModel(model)
                                }
                                downloadViewModel.selectModel(model)
                                Task { await downloadViewModel.loadModel() }
                            } else {
                                downloadViewModel.selectModel(model)
                            }
                        }
                    )
                }
            }

            NavigationLink("Download Vision Models") {
                ModelDownloadView(viewModel: downloadViewModel, capabilityFilter: .vision)
            }
        } header: {
            Text("Vision Model")
        } footer: {
            if !viewModel.availableVisionModels.isEmpty {
                Text("Vision models process photo attachments. Integrated models handle both text and vision — no separate selection needed.")
            }
        }
    }

    // MARK: - Model Row Helpers

    @ViewBuilder
    func modelRow(
        model: ModelInfo,
        isSelected: Bool,
        isLoaded: Bool,
        onSelect: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.subheadline)
                    capabilityBadges(for: model)
                }
                HStack(spacing: 8) {
                    Text(model.isDownloaded ? "On device" : "Not downloaded")
                        .font(.caption)
                        .foregroundStyle(model.isDownloaded ? .green : .secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(model.fileSizeGB < 1
                        ? String(format: "%.0f MB", model.fileSizeGB * 1024)
                        : String(format: "%.1f GB", model.fileSizeGB))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.accentColor)
            } else if isLoaded {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(.green)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .swipeActions(edge: .trailing) {
            if model.isDownloaded {
                Button("Delete", role: .destructive) {
                    downloadViewModel.deleteModel(model)
                }
            }
        }
    }

    @ViewBuilder
    func capabilityBadges(for model: ModelInfo) -> some View {
        if model.isIntegrated {
            badge("Integrated", icon: "sparkles", color: .purple)
        } else if model.supportsVision {
            badge("Vision", icon: "camera.viewfinder", color: .orange)
        }
    }

    @ViewBuilder
    func badge(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}
