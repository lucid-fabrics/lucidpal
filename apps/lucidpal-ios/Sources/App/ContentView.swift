import SwiftUI

struct ContentView: View {

    // MARK: - Dependencies

    @ObservedObject var sessionListViewModel: SessionListViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var downloadViewModel: ModelDownloadViewModel

    @State private var selectedTab: Tab = .chat
    @State private var showDownloadFailedAlert = false
    @State private var downloadFailedAlertMessage = ""
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {
            SessionListView(viewModel: sessionListViewModel)
                .tabItem {
                    Label(Tab.chat.title, systemImage: Tab.chat.icon)
                }
                .tag(Tab.chat)

            SettingsView(viewModel: settingsViewModel, downloadViewModel: downloadViewModel)
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
        .onChange(of: selectedTab) { _, _ in
            let selection = UISelectionFeedbackGenerator()
            selection.prepare()
            selection.selectionChanged()
        }
        // Fix: condition lives at call site so SwiftUI sees the view enter/exit
        // and the transition fires within the animation context from value:.
        .overlay(alignment: .top) {
            if isDownloading {
                Button {
                    selectedTab = .settings
                    let sel = UISelectionFeedbackGenerator()
                    sel.prepare()
                    sel.selectionChanged()
                } label: {
                    DownloadProgressPill(
                        progress: downloadProgress,
                        modelName: downloadViewModel.selectedModel.displayName,
                        hasPendingVision: downloadViewModel.pendingVisionDownload != nil
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .none : .spring(duration: 0.5, bounce: 0.2), value: isDownloading)
        // Fix: surface download failures that occur after onboarding dismissal.
        .onChange(of: downloadViewModel.downloadState) { _, state in
            if case .failed(let message) = state {
                // Set message before toggling presentation so Text is never empty
                // during the alert's appear animation.
                downloadFailedAlertMessage = message
                showDownloadFailedAlert = true
            }
        }
        .alert("Model Download Failed", isPresented: $showDownloadFailedAlert) {
            Button("OK") { }
        } message: {
            Text(downloadFailedAlertMessage)
        }
    }

    private var isDownloading: Bool {
        if case .downloading = downloadViewModel.downloadState { return true }
        return false
    }

    private var downloadProgress: Double {
        if case .downloading(let p) = downloadViewModel.downloadState { return max(0, min(p, 1.0)) }
        return 0
    }
}

// MARK: - Download progress pill

private struct DownloadProgressPill: View {
    let progress: Double
    let modelName: String
    let hasPendingVision: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: min(progress, 1.0))
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(min(progress, 1.0) * 100))%")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text("Downloading \(modelName)…")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                if hasPendingVision {
                    Text("Vision model queued")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.75))
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.92))
        .clipShape(Capsule())
        .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 3)
    }
}

// MARK: - Tab

private enum Tab {
    case chat
    case settings

    var title: String {
        switch self {
        case .chat: return "Chat"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .settings: return "gear"
        }
    }
}
