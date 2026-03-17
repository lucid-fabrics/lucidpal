import SwiftUI

struct ContentView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var downloadViewModel: ModelDownloadViewModel

    var body: some View {
        TabView {
            ChatView(viewModel: chatViewModel)
                .tabItem {
                    Label("Chat", systemImage: "bubble.left.and.bubble.right")
                }

            SettingsView(viewModel: settingsViewModel, downloadViewModel: downloadViewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
