import SwiftUI

struct AgentHubView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        List {
            Section {
                HStack(spacing: 14) { ProfileAvatar(name: store.selectedProfile, avatar: store.profile?.avatar, size: 58); VStack(alignment: .leading, spacing: 4) { Text(store.selectedProfile).font(.title3.bold()); Text(store.profile?.model ?? String(localized: "Hermes agent")).font(.subheadline).foregroundStyle(.secondary); StatusPill(text: store.profile?.active == true ? String(localized: "Active") : String(localized: "Ready"), color: .green) }; Spacer() }.padding(.vertical, 7)
            }
            Section("Work") {
                NavigationLink { InsightsView() } label: { AgentToolRow(icon: "chart.xyaxis.line", color: .purple, title: "Insights", detail: "Token usage and Studio runtime") }
                NavigationLink { CronJobsView() } label: { AgentToolRow(icon: "calendar.badge.clock", color: .blue, title: "Scheduled Jobs", detail: "Automations, schedules and delivery") }
                NavigationLink { KanbanView() } label: { AgentToolRow(icon: "rectangle.3.group", color: .orange, title: "Kanban", detail: "Plan work with a touch-first board") }
                NavigationLink { ChannelsView() } label: { AgentToolRow(icon: "antenna.radiowaves.left.and.right", color: .green, title: "Channels", detail: "Connect every messaging platform") }
            }
            Section("Capabilities") {
                NavigationLink { SkillsView() } label: { AgentToolRow(icon: "square.stack.3d.up.fill", color: .indigo, title: "Skills", detail: "Manage and edit agent instructions") }
                NavigationLink { PluginsView() } label: { AgentToolRow(icon: "puzzlepiece.extension.fill", color: .purple, title: "Plugins", detail: "Enable installed extensions") }
                NavigationLink { MCPView() } label: { AgentToolRow(icon: "server.rack", color: .cyan, title: "MCP", detail: "Connect tools and external servers") }
                NavigationLink { PetsView() } label: { AgentToolRow(icon: "pawprint.fill", color: .pink, title: "Pets", detail: "Adopt and manage agent companions") }
            }
            Section("Intelligence") {
                NavigationLink { StudioSectionSettings(section: .memory) } label: { AgentToolRow(icon: "lightbulb.max.fill", color: .yellow, title: "Memory", detail: "Control long-term context") }
                NavigationLink { ModelsView() } label: { AgentToolRow(icon: "cpu.fill", color: .mint, title: "Models", detail: "Choose models and providers") }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Agent")
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarLeading) { ProfileMenu() }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarLeading) { ProfileMenu() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
            }
        }
    }
}
