import SwiftUI

struct ContentView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var downloadViewModel: ModelDownloadViewModel

    var body: some View {
        TabView {
            ChatView(viewModel: chatViewModel)
                .tabItem {
                    Label(Tab.chat.title, systemImage: Tab.chat.icon)
                }

            SettingsView(viewModel: settingsViewModel, downloadViewModel: downloadViewModel)
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.icon)
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
