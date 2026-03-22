import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var downloadViewModel: ModelDownloadViewModel

    private static let sourceURL = URL(string: "https://github.com/wassimmehanna/pocketmind")

    var body: some View {
        NavigationStack {
            Form {
                calendarSection
                modelSection
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
                Toggle("Use calendar in chat", isOn: Binding(
                    get: { viewModel.settings.calendarAccessEnabled },
                    set: { viewModel.settings.calendarAccessEnabled = $0 }
                ))

                let calendars = viewModel.availableCalendars
                if !calendars.isEmpty {
                    Picker("Default Calendar", selection: Binding(
                        get: {
                            viewModel.settings.defaultCalendarIdentifier.isEmpty
                                ? nil
                                : viewModel.settings.defaultCalendarIdentifier
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

    private var modelSection: some View {
        Section {
            ForEach(downloadViewModel.availableModels, id: \.id) { model in
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
                            .foregroundStyle(Color.accentColor)
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
            Text("Device RAM: \(viewModel.settings.deviceRAMGB) GB · Free storage: \(viewModel.availableStorageGB.map { String(format: "%.1f GB free", $0) } ?? "Unknown")")
        }
    }

    private var inferenceSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { viewModel.settings.thinkingEnabled },
                set: { viewModel.settings.thinkingEnabled = $0 }
            )) {
                Label("Thinking Mode", systemImage: "brain")
            }
            Toggle(isOn: Binding(
                get: { viewModel.settings.voiceAutoStartEnabled },
                set: { viewModel.setVoiceAutoStart($0) }
            )) {
                Label("Start voice on open", systemImage: "waveform.and.mic")
            }
            Toggle(isOn: Binding(
                get: { viewModel.settings.airpodsAutoVoiceEnabled },
                set: { viewModel.settings.airpodsAutoVoiceEnabled = $0 }
            )) {
                Label("AirPods auto-voice", systemImage: "airpodspro")
            }
            if !viewModel.settings.voiceAutoStartEnabled {
                Toggle(isOn: Binding(
                    get: { viewModel.settings.speechAutoSendEnabled },
                    set: { viewModel.settings.speechAutoSendEnabled = $0 }
                )) {
                    Label("Auto-send after speech", systemImage: "mic.badge.auto")
                }
            }
            contextSizePicker
        } header: {
            Text("Inference")
        } footer: {
            Text("Thinking mode reasons before answering (slower but more accurate). \"Start voice on open\" automatically starts listening when you open a new chat. \"AirPods auto-voice\" starts listening automatically when AirPods are connected. Auto-send submits voice input when speech recognition finishes.")
        }
    }

    @ViewBuilder
    private var contextSizePicker: some View {
        let maxCtx = viewModel.settings.maxContextSize
        VStack(alignment: .leading, spacing: 0) {
            Picker(selection: Binding(
                get: { min(viewModel.settings.contextSize, maxCtx) },
                set: { viewModel.settings.contextSize = $0 }
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

    private var shortcutsSection: some View {
        Section("Shortcuts Integration") {
            VStack(alignment: .leading, spacing: 8) {
                Text("PocketMind actions are available in the Shortcuts app for automation.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    shortcutRow(icon: "brain.head.profile", title: "Ask PocketMind", description: "Query AI assistant and get text response")
                    shortcutRow(icon: "calendar.badge.plus", title: "Create Event", description: "Add calendar event with title, time, duration")
                    shortcutRow(icon: "calendar.badge.clock", title: "Check Next Meeting", description: "Get details of upcoming calendar event")
                    shortcutRow(icon: "clock.badge.checkmark", title: "Find Free Time", description: "Search for available time slots")
                }
            }
            .padding(.vertical, 4)

            if let shortcutsURL = URL(string: "shortcuts://") {
                Link(destination: shortcutsURL) {
                    HStack {
                        Label("Open Shortcuts App", systemImage: "link")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func shortcutRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.blue)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: Self.appVersion)
            LabeledContent("Inference", value: "On-device (llama.cpp)")
            if let url = Self.sourceURL {
                Link("Source Code", destination: url)
            }
        }
    }

    private static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
