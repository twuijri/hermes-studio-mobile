import SwiftUI

struct RootTabs: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        TabView(selection: $store.selectedRootTab) {
            NavigationStack { ChatsView().id(store.languageRefresh) }.tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right.fill") }.tag(0)
            NavigationStack { GroupsView().id(store.languageRefresh) }.tabItem { Label("Groups", systemImage: "person.3.fill") }.tag(1)
            NavigationStack { AgentHubView().id(store.languageRefresh) }.tabItem { Label("Agent", systemImage: "sparkles") }.tag(2)
        }
    }
}
