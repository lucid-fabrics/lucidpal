import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var downloadViewModel: ModelDownloadViewModel

    private static let sourceURL = URL(string: "https://github.com/wassimmehanna/pocketmind")!

    var body: some View {
        NavigationStack {
            Form {
                calendarSection
                modelSection
                aboutSection
            }
            .navigationTitle("Settings")
            .alert("Delete Error", isPresented: .constant(downloadViewModel.deleteError != nil)) {
                Button("OK") { downloadViewModel.deleteError = nil }
            } message: {
                Text(downloadViewModel.deleteError ?? "")
            }
        }
    }

    private var calendarSection: some View {
        Section {
            HStack {
                Label("Calendar Access", systemImage: "calendar")
                Spacer()
                statusBadge
            }

            if !viewModel.isCalendarAuthorized {
                Button("Allow Calendar Access") {
                    Task { await viewModel.requestCalendarAccess() }
                }
                .foregroundStyle(.accent)
            } else {
                Toggle("Use calendar in chat", isOn: Binding(
                    get: { viewModel.settings.calendarAccessEnabled },
                    set: { viewModel.settings.calendarAccessEnabled = $0 }
                ))
            }
        } header: {
            Text("Calendar")
        } footer: {
            Text("When enabled, upcoming events are included in the AI prompt. All processing is on-device.")
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if viewModel.isCalendarAuthorized {
            Text("Granted")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        } else {
            Text("Not granted")
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
        }
    }

    private var modelSection: some View {
        Section {
            ForEach(downloadViewModel.availableModels) { model in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.displayName)
                            .font(.subheadline)
                        Text(model.isDownloaded ? "On device" : "Not downloaded")
                            .font(.caption)
                            .foregroundStyle(model.isDownloaded ? .green : .secondary)
                    }
                    Spacer()
                    if viewModel.settings.selectedModelID == model.id && downloadViewModel.isModelLoaded {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.accent)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if model.isDownloaded {
                        viewModel.selectModel(model)
                        downloadViewModel.selectModel(model)  // cancels prior download, updates selection
                        Task { await downloadViewModel.loadModel() }
                    } else {
                        downloadViewModel.selectModel(model)  // pre-selects for the download flow
                    }
                }
                .swipeActions(edge: .trailing) {
                    if model.isDownloaded {
                        Button("Delete", role: .destructive) {
                            downloadViewModel.deleteModel(model)
                        }
                    }
                }
            }

            NavigationLink("Download Models") {
                ModelDownloadView(viewModel: downloadViewModel)
            }
        } header: {
            Text("Model")
        } footer: {
            Text("Device RAM: \(viewModel.settings.deviceRAMGB) GB")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0.0")
            LabeledContent("Inference", value: "On-device (llama.cpp)")
            Link("Source Code", destination: Self.sourceURL)
        }
    }
}
