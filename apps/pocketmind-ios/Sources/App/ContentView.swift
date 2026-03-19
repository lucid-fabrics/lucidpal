import SwiftUI

struct ContentView: View {

    // MARK: - Dependencies

    @ObservedObject var sessionListViewModel: SessionListViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var downloadViewModel: ModelDownloadViewModel
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    // MARK: - Body

    var body: some View {
        Group {
            if hasSeenOnboarding {
                TabView {
                    SessionListView(viewModel: sessionListViewModel)
                        .tabItem {
                            Label(Tab.chat.title, systemImage: Tab.chat.icon)
                        }

                    SettingsView(viewModel: settingsViewModel, downloadViewModel: downloadViewModel)
                        .tabItem {
                            Label(Tab.settings.title, systemImage: Tab.settings.icon)
                        }
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
