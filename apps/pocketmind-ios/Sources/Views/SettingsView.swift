import CoreLocation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var downloadViewModel: ModelDownloadViewModel

    private static let sourceURL = URL(string: "https://github.com/wassimmehanna/pocketmind")

    var body: some View {
        NavigationStack {
            Form {
                calendarSection
                locationSection
                webSearchSection
                visionSection
                textModelSection
                visionModelSection
                inferenceSection
                shortcutsSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .alert("Delete Error", isPresented: .constant(downloadViewModel.deleteError != nil)) {
                Button("OK") { downloadViewModel.deleteError = nil }
            } message: {
                Text(downloadViewModel.deleteError ?? "")
            }
        }
    }

    // MARK: - Sections

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
                .foregroundStyle(Color.accentColor)
            } else {
                Toggle("Use calendar in chat", isOn: $viewModel.calendarAccessEnabled)

                let calendars = viewModel.availableCalendars
                if !calendars.isEmpty {
                    Picker("Default Calendar", selection: Binding(
                        get: {
                            viewModel.defaultCalendarIdentifier.isEmpty
                                ? nil
                                : viewModel.defaultCalendarIdentifier
                        },
                        set: { viewModel.setDefaultCalendar(id: $0) }
                    )) {
                        Text("System Default").tag(Optional<String>.none)
                        ForEach(calendars) { cal in
                            Text(cal.title).tag(Optional(cal.id))
                        }
                    }
                }
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

    private var locationSection: some View {
        Section {
            HStack {
                Label("Location", systemImage: "location")
                Spacer()
                locationStatusBadge
            }

            if viewModel.isLocationServiceUnavailable {
                Text("Location service unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if viewModel.locationStatus == .denied || viewModel.locationStatus == .restricted {
                Text("Location access denied. Enable it in Settings → Privacy → Location Services.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                if viewModel.locationEnabled && !viewModel.userCity.isEmpty {
                    Toggle("Include city in AI context", isOn: $viewModel.locationEnabled)
                    LabeledContent("Detected city", value: viewModel.userCity)
                    Button(viewModel.isResolvingCity ? "Detecting…" : "Refresh Location") {
                        Task { await viewModel.requestLocationAccess() }
                    }
                    .disabled(viewModel.isResolvingCity)
                } else {
                    Button(viewModel.isResolvingCity ? "Detecting…" : "Enable Location") {
                        Task { await viewModel.requestLocationAccess() }
                    }
                    .disabled(viewModel.isResolvingCity)
                }
            }
        } header: {
            Text("Location")
        } footer: {
            Text("When enabled, your city is included in the AI prompt so responses like weather and local recommendations are relevant to you. Location is never stored on servers.")
        }
    }

    @ViewBuilder
    private var locationStatusBadge: some View {
        if viewModel.locationEnabled && !viewModel.userCity.isEmpty {
            Text("On · \(viewModel.userCity)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.green)
        } else {
            Text("Off")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var webSearchSection: some View {
        Section("Web Search") {
            NavigationLink {
                WebSearchSettingsView(viewModel: viewModel)
            } label: {
                HStack {
                    Label("Web Search", systemImage: "globe")
                    Spacer()
                    Text(viewModel.webSearchSummary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var visionSection: some View {
        Section {
            Toggle(isOn: $viewModel.visionEnabled) {
                Label("Vision", systemImage: "camera.viewfinder")
            }
        } footer: {
            Text("When enabled, photo attachments are processed by the vision model. Disable to only use text inference.")
        }
    }

    // MARK: - Model Sections

    private var textModelSection: some View {
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

    private var visionModelSection: some View {
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
                        isLoaded: false,   // vision model loaded on-demand; don't show as "loaded" here
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

    @ViewBuilder
    private func modelRow(
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
    private func capabilityBadges(for model: ModelInfo) -> some View {
        if model.isIntegrated {
            badge("Integrated", icon: "sparkles", color: .purple)
        } else if model.supportsVision {
            badge("Vision", icon: "camera.viewfinder", color: .orange)
        }
    }

    @ViewBuilder
    private func badge(_ text: String, icon: String, color: Color) -> some View {
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

    // MARK: - Inference

    private var inferenceSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { viewModel.voiceAutoStartEnabled },
                set: { viewModel.setVoiceAutoStart($0) }
            )) {
                Label("Start voice on open", systemImage: "waveform.and.mic")
            }
            Toggle(isOn: $viewModel.airpodsAutoVoiceEnabled) {
                Label("AirPods auto-voice", systemImage: "airpodspro")
            }
            if !viewModel.voiceAutoStartEnabled {
                Toggle(isOn: $viewModel.speechAutoSendEnabled) {
                    Label("Auto-send after speech", systemImage: "mic.badge.auto")
                }
            }
            contextSizePicker
        } header: {
            Text("Inference")
        } footer: {
            Text("\"Start voice on open\" automatically starts listening when you open a new chat. \"AirPods auto-voice\" starts listening automatically when AirPods are connected. Auto-send submits voice input when speech recognition finishes. Thinking mode can be toggled per chat via the brain icon in the chat toolbar.")
        }
    }

    @ViewBuilder
    private var contextSizePicker: some View {
        let maxCtx = viewModel.maxContextSize
        VStack(alignment: .leading, spacing: 0) {
            Picker(selection: Binding(
                get: { min(viewModel.contextSize, maxCtx) },
                set: { viewModel.contextSize = $0 }
            )) {
                ForEach([2048, 4096, 8192].filter { $0 <= maxCtx }, id: \.self) { size in
                    Text("\(size) tokens").tag(size)
                }
            } label: {
                Label("Context Window", systemImage: "memorychip")
            }
            .pickerStyle(.menu)

            Text("How many tokens the model keeps in memory. Larger = longer conversations but slower load and more RAM. Takes effect next time the model loads. Your device supports up to \(maxCtx) tokens.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Self.appVersion)
            LabeledContent("Inference", value: "On-device (llama.cpp)")
            if let url = Self.sourceURL {
                Link("Source Code", destination: url)
            }
            NavigationLink {
                DebugLogView()
            } label: {
                Label("Debug Logs", systemImage: "terminal")
            }
        }
    }

    private static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
