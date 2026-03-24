import SwiftUI

struct ContentView: View {

    // MARK: - Dependencies

    @ObservedObject var sessionListViewModel: SessionListViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var downloadViewModel: ModelDownloadViewModel
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var selectedTab: Tab = .chat

    // MARK: - Body

    var body: some View {
        Group {
            if hasSeenOnboarding {
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
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            } else {
                OnboardingCarouselView()
            }
        }
    }
}

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
