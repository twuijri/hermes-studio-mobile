import SwiftUI

struct RootTabs: View {
    @State private var selection = 0
    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { ChatsView() }.tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right.fill") }.tag(0)
            NavigationStack { GroupsView() }.tabItem { Label("Groups", systemImage: "person.3.fill") }.tag(1)
            NavigationStack { AgentHubView() }.tabItem { Label("Agent", systemImage: "sparkles") }.tag(2)
        }
    }
}
