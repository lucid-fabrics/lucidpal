import SwiftUI

private enum TestState {
    case idle
    case testing
    case success(Int)   // result count
    case failure(String)

    var label: String {
        switch self {
        case .idle:              return "Test Connection"
        case .testing:           return "Testing…"
        case .success(let n):    return "✓ Connected — \(n) result\(n == 1 ? "" : "s") returned"
        case .failure(let msg):  return "✗ \(msg)"
        }
    }

    var color: Color {
        switch self {
        case .idle, .testing: return .accentColor
        case .success:        return .green
        case .failure:        return .red
        }
    }
}

struct WebSearchSettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var testState: TestState = .idle
    @State private var showJsonInfo = false

    var body: some View {
        Form {
            enableSection
            if viewModel.webSearchEnabled {
                providerSection
                configSection
            }
        }
        .navigationTitle("Web Search")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var enableSection: some View {
        Section {
            Toggle(isOn: $viewModel.webSearchEnabled) {
                Label("Enable Web Search", systemImage: "globe")
            }
        } footer: {
            Text("When enabled, PocketMind can search the web to answer questions about current events and real-time data.")
        }
    }

    private var providerSection: some View {
        Section {
            Picker("Provider", selection: $viewModel.webSearchProvider) {
                Text(WebSearchProvider.brave.displayName).tag(WebSearchProvider.brave)
                Text(WebSearchProvider.searxng.displayName).tag(WebSearchProvider.searxng)
            }
        } header: {
            Text("Provider")
        }
    }

    @ViewBuilder
    private var configSection: some View {
        switch viewModel.webSearchProvider {
        case .brave:
            braveSection
        case .searxng:
            searxngSection
        }
    }

    // MARK: - Provider config

    private var braveSection: some View {
        Section {
            SecureField("API Key", text: $viewModel.braveApiKey)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            testButton
        } header: {
            Text("Brave Search API")
        } footer: {
            Text("Get a free API key at search.brave.com/app/keys (2,000 queries/month free). Your key is stored only on this device.")
        }
    }

    private var searxngSection: some View {
        Section {
            TextField("http://192.168.1.x:8888", text: $viewModel.webSearchEndpoint)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button {
                showJsonInfo = true
            } label: {
                Label("JSON format must be enabled", systemImage: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showJsonInfo) {
                jsonInfoSheet
            }
            testButton
        } header: {
            Text("SearXNG Endpoint")
        } footer: {
            Text("On first search, iOS will ask for local network permission — tap Allow.")
        }
    }

    private var jsonInfoSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Text("SearXNG disables JSON output by default. You must enable it in your instance's settings.yml before PocketMind can fetch results.")
                } header: {
                    Text("Why is this needed?")
                }
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("1. Open your settings.yml")
                            .font(.subheadline).fontWeight(.medium)
                        Text("Typically at /mnt/user/appdata/searxng/settings.yml on Unraid.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("2. Find the formats block and add json")
                            .font(.subheadline).fontWeight(.medium)
                        Text("search:\n  formats:\n    - html\n    - json")
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3. Restart SearXNG")
                            .font(.subheadline).fontWeight(.medium)
                        Text("docker restart SearXNG")
                            .font(.system(.caption, design: .monospaced))
                            .padding(8)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                } header: {
                    Text("How to enable it")
                }
                Section {
                    Text("Use the Test Connection button — it will confirm JSON is working and show how many results are returned.")
                } header: {
                    Text("Verify")
                }
            }
            .navigationTitle("SearXNG JSON Format")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showJsonInfo = false }
                }
            }
        }
    }

    private var testButton: some View {
        Button {
            Task { await runTest() }
        } label: {
            HStack {
                if case .testing = testState {
                    ProgressView().scaleEffect(0.8)
                }
                Text(testState.label)
                    .foregroundStyle(testState.color)
            }
        }
        .disabled({ if case .testing = testState { return true }; return false }())
    }

    private func runTest() async {
        testState = .testing
        let svc = viewModel.makeWebSearchService()
        do {
            let results = try await svc.search(query: "test", maxResults: 3)
            testState = .success(results.count)
        } catch {
            testState = .failure(error.localizedDescription)
        }
    }
}
