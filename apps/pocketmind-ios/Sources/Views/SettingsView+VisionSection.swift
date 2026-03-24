import SwiftUI

// MARK: - Vision & Model Sections

extension SettingsView {
    var visionSection: some View {
        Section {
            Toggle(isOn: $viewModel.visionEnabled) {
                Label("Vision", systemImage: "camera.viewfinder")
            }
        } header: {
            sectionHeader("Vision", icon: "eye.fill", color: .orange)
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

            NavigationLink {
                ModelDownloadView(viewModel: downloadViewModel, capabilityFilter: .text)
            } label: {
                Label("Download More Models", systemImage: "arrow.down.circle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.accentColor)
            }
        } header: {
            sectionHeader("Text Model", icon: "cpu", color: .purple)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "internaldrive")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("RAM: \(viewModel.deviceRAMGB) GB")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(viewModel.availableStorageGB.map { String(format: "%.1f GB free", $0) } ?? "Unknown")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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

            NavigationLink {
                ModelDownloadView(viewModel: downloadViewModel, capabilityFilter: .vision)
            } label: {
                Label("Download Vision Models", systemImage: "arrow.down.circle")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.accentColor)
            }
        } header: {
            sectionHeader("Vision Model", icon: "camera.viewfinder", color: .pink)
        } footer: {
            if !viewModel.availableVisionModels.isEmpty {
                Text("Vision models process photo attachments. Integrated models handle both text and vision.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        HStack(spacing: 12) {
            // Model icon
            Image(systemName: model.supportsVision ? "camera.viewfinder" : "cpu")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(isSelected ? .white : (model.supportsVision ? Color.orange : Color.purple))
                .frame(width: 32, height: 32)
                .background(
                    isSelected
                        ? AnyShapeStyle(Color.accentColor)
                        : AnyShapeStyle(model.supportsVision ? Color.orange.opacity(0.12) : Color.purple.opacity(0.12)),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .font(.subheadline.weight(.medium))
                    capabilityBadges(for: model)
                }
                HStack(spacing: 6) {
                    // Download status
                    HStack(spacing: 3) {
                        Circle()
                            .fill(model.isDownloaded ? Color.green : Color(.systemGray4))
                            .frame(width: 6, height: 6)
                        Text(model.isDownloaded ? "On device" : "Not downloaded")
                            .font(.caption2)
                            .foregroundStyle(model.isDownloaded ? .green : .secondary)
                    }
                    Text("·")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(model.fileSizeGB < 1
                        ? String(format: "%.0f MB", model.fileSizeGB * 1024)
                        : String(format: "%.1f GB", model.fileSizeGB))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.bounce, value: isSelected)
            }
        }
        .padding(.vertical, 2)
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
                .font(.system(size: 9, weight: .bold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12), in: Capsule())
    }
}
