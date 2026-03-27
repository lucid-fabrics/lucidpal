import CoreLocation
import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var downloadViewModel: ModelDownloadViewModel
    @State private var showDeleteError = false
    #if DEBUG
    @State private var showUnsupportedDevicePreview = false
    #endif

    var body: some View {
        NavigationStack {
            Form {
                // Data Sources
                calendarSection
                locationSection
                webSearchSection

                // AI Models
                visionSection
                textModelSection
                visionModelSection

                // Interaction
                inferenceSection

                // Integration
                shortcutsSection

                // App
                aboutSection
                #if DEBUG
                debugSection
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            #if DEBUG
            .fullScreenCover(isPresented: $showUnsupportedDevicePreview) {
                UnsupportedDeviceView()
                    .overlay(alignment: .topTrailing) {
                        Button("Done") { showUnsupportedDevicePreview = false }
                            .font(.body.weight(.semibold)).padding(.horizontal, 20).padding(.top, 60)
                    }
            }
            #endif
            .onChange(of: downloadViewModel.deleteError) { _, error in
                if error != nil { showDeleteError = true }
            }
            .alert("Delete Error", isPresented: $showDeleteError) {
                Button("OK") { downloadViewModel.deleteError = nil }
            } message: {
                Text(downloadViewModel.deleteError ?? "")
            }
        }
    }

    // MARK: - Section Header Helper

    @ViewBuilder
    func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        Label {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .textCase(nil)
        } icon: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(color, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
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
            sectionHeader("Calendar", icon: "calendar", color: .red)
        } footer: {
            Text("When enabled, upcoming events are included in the AI prompt. All processing is on-device.")
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let granted = viewModel.isCalendarAuthorized
        Text(granted ? "Granted" : "Not granted")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(granted ? .green : .orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background((granted ? Color.green : Color.orange).opacity(0.12), in: Capsule())
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
            sectionHeader("Location", icon: "location.fill", color: .blue)
        } footer: {
            // swiftlint:disable:next line_length
            Text("When enabled, your city is included in the AI prompt so responses like weather and local recommendations are relevant to you. Location is never stored on servers.")
        }
    }

    @ViewBuilder
    private var locationStatusBadge: some View {
        if viewModel.locationEnabled && !viewModel.userCity.isEmpty {
            Text(viewModel.userCity)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.green.opacity(0.12), in: Capsule())
        } else {
            Text("Off")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(.systemGray5), in: Capsule())
        }
    }

    private var webSearchSection: some View {
        Section {
            NavigationLink {
                WebSearchSettingsView(viewModel: viewModel)
            } label: {
                HStack {
                    Label("Web Search", systemImage: "globe")
                    Spacer()
                    Text(viewModel.webSearchSummary)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(viewModel.webSearchEnabled ? .cyan : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            (viewModel.webSearchEnabled ? Color.cyan : Color(.systemGray5))
                                .opacity(viewModel.webSearchEnabled ? 0.12 : 1),
                            in: Capsule()
                        )
                }
            }
        } header: {
            sectionHeader("Web Search", icon: "globe", color: .cyan)
        }
    }

    // MARK: - Inference

    var inferenceSection: some View {
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
            sectionHeader("Inference", icon: "waveform", color: .indigo)
        } footer: {
            Text(
                "\"Start voice on open\" automatically starts listening when you open a new chat. " +
                "\"AirPods auto-voice\" starts listening automatically when AirPods are connected. " +
                "Auto-send submits voice input when speech recognition finishes. " +
                "Thinking mode can be toggled per chat via the brain icon in the chat toolbar."
            )
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

            // swiftlint:disable:next line_length
            Text("How many tokens the model keeps in memory. Larger = longer conversations but slower load and more RAM. Takes effect next time the model loads. Your device supports up to \(maxCtx) tokens.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
    }

    private var aboutSection: some View {
        Section {
            // App identity hero
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(.white)
                    }
                VStack(alignment: .leading, spacing: 3) {
                    Text("LucidPal")
                        .font(.headline)
                    Text("Version \(Self.appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("On-device AI · llama.cpp")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)

            NavigationLink {
                DebugLogView()
            } label: {
                Label("Debug Logs", systemImage: "terminal")
            }
        } header: {
            sectionHeader("About", icon: "info.circle.fill", color: .gray)
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section {
            Button {
                viewModel.replayOnboarding()
            } label: {
                Label("Replay Onboarding", systemImage: "arrow.counterclockwise")
            }
            Button { showUnsupportedDevicePreview = true } label: {
                Label("Preview Unsupported Device Screen", systemImage: "memorychip")
            }
            Button(role: .destructive) {
                if let domain = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: domain)
                }
            } label: {
                Label("Reset All Settings", systemImage: "trash")
                    .foregroundStyle(.red)
            }
        } header: {
            sectionHeader("Developer", icon: "wrench.and.screwdriver", color: .yellow)
        }
    }
    #endif

    private static var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}
