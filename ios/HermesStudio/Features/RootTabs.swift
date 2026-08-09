import SwiftUI

struct RootTabs: View {
    @EnvironmentObject private var store: AppStore
    @State private var chatsStackID = UUID()
    @State private var groupsStackID = UUID()
    @State private var agentStackID = UUID()

    var body: some View {
        TabView(selection: rootSelection) {
            NavigationStack { ChatsView().id(store.languageRefresh) }
                .id(chatsStackID)
                .tabItem { Label("Chats", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(0)
            NavigationStack { GroupsView().id(store.languageRefresh) }
                .id(groupsStackID)
                .tabItem { Label("Groups", systemImage: "person.3.fill") }
                .tag(1)
            NavigationStack { AgentHubView().id(store.languageRefresh) }
                .id(agentStackID)
                .tabItem { Label("Agent", systemImage: "sparkles") }
                .tag(2)
        }
    }

    private var rootSelection: Binding<Int> {
        Binding(
            get: { store.selectedRootTab },
            set: { selectedTab in
                // Each root tab owns its own navigation stack. Reset the destination
                // stack whenever the user enters it so Settings and other detail pages
                // never survive a round-trip through another tab.
                switch selectedTab {
                case 0: chatsStackID = UUID()
                case 1: groupsStackID = UUID()
                default: agentStackID = UUID()
                }
                store.selectedRootTab = selectedTab
            }
        )
    }
}
