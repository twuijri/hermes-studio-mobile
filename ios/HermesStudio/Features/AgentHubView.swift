import SwiftUI

struct AgentHubView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        List {
            Section {
                HStack(spacing: 14) { ProfileAvatar(name: store.selectedProfile, avatar: store.profile?.avatar, size: 58); VStack(alignment: .leading, spacing: 4) { Text(store.selectedProfile).font(.title3.bold()); Text(store.profile?.model ?? String(localized: "Hermes agent")).font(.subheadline).foregroundStyle(.secondary); StatusPill(text: store.profile?.active == true ? String(localized: "Active") : String(localized: "Ready"), color: .green) }; Spacer() }.padding(.vertical, 7)
            }
            Section("Work") {
                NavigationLink { AgentManagerView() } label: { AgentToolRow(icon: "cpu", color: .blue, title: "Agents", detail: "Choose and manage every agent runtime") }
                NavigationLink { InsightsView() } label: { AgentToolRow(icon: "chart.xyaxis.line", color: .purple, title: "Insights", detail: "Token usage and Studio runtime") }
                NavigationLink { CronJobsView() } label: { AgentToolRow(icon: "calendar.badge.clock", color: .blue, title: "Scheduled Jobs", detail: "Automations, schedules and delivery") }
                NavigationLink { KanbanView() } label: { AgentToolRow(icon: "rectangle.3.group", color: .orange, title: "Kanban", detail: "Plan work with a touch-first board") }
                NavigationLink { ChannelsView() } label: { AgentToolRow(icon: "antenna.radiowaves.left.and.right", color: .green, title: "Channels", detail: "Connect every messaging platform") }
            }
            Section("Capabilities") {
                NavigationLink { SkillsView() } label: { AgentToolRow(icon: "square.stack.3d.up.fill", color: .indigo, title: "Skills", detail: "Manage and edit agent instructions") }
                NavigationLink { PluginsView() } label: { AgentToolRow(icon: "puzzlepiece.extension.fill", color: .purple, title: "Plugins", detail: "Enable installed extensions") }
                NavigationLink { MCPView() } label: { AgentToolRow(icon: "server.rack", color: .cyan, title: "MCP", detail: "Connect tools and external servers") }
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

struct AgentManagerView: View {
    @EnvironmentObject private var store: AppStore
    @State private var statuses: [AgentRuntimeStatus] = []
    @State private var tools: [CodingAgentTool] = []
    @State private var loading = true
    @State private var workingID: String?
    @State private var deleteCandidate: AgentDescriptor?

    private let descriptors = [
        AgentDescriptor(id: "ekko-agent", name: "Ekko", provider: "Studio", symbol: "sparkles", tint: .purple, builtIn: true),
        AgentDescriptor(id: "hermes", name: "Hermes", provider: "Nous Research", symbol: "bolt.horizontal.circle.fill", tint: .green, builtIn: false),
        AgentDescriptor(id: "claude-code", name: "Claude Code", provider: "Anthropic", symbol: "c.circle.fill", tint: .orange, builtIn: false),
        AgentDescriptor(id: "codex", name: "Codex", provider: "OpenAI", symbol: "chevron.left.forwardslash.chevron.right", tint: .mint, builtIn: false),
        AgentDescriptor(id: "pi", name: "Pi", provider: "Pi", symbol: "command.circle.fill", tint: .blue, builtIn: false),
    ]

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Agent family", systemImage: "square.grid.2x2.fill").font(.headline)
                    Text("Select the right runtime for each conversation. Built-in, managed Runtime, and local CLI agents stay clearly separated.").font(.subheadline).foregroundStyle(.secondary)
                }.padding(.vertical, 5)
            }
            Section("Built in") { agentRow(descriptors[0]) }
            Section("Hermes runtime") { agentRow(descriptors[1]) }
            Section("Coding agents") { ForEach(descriptors.dropFirst(2)) { agentRow($0) } }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Agents")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { Task { await load() } } label: { loading ? AnyView(ProgressView()) : AnyView(Image(systemName: "arrow.clockwise")) }.disabled(loading) } }
        .task { await load() }
        .confirmationDialog("Remove agent?", isPresented: Binding(get: { deleteCandidate != nil }, set: { if !$0 { deleteCandidate = nil } }), titleVisibility: .visible) {
            if let candidate = deleteCandidate { Button("Remove \(candidate.name)", role: .destructive) { Task { await remove(candidate) } } }
            Button("Cancel", role: .cancel) {}
        }
    }

    @ViewBuilder private func agentRow(_ descriptor: AgentDescriptor) -> some View {
        let state = status(for: descriptor.id)
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 13) {
                Image(systemName: descriptor.symbol).font(.title2).foregroundStyle(descriptor.tint).frame(width: 42, height: 42).background(descriptor.tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    HStack { Text(descriptor.name).font(.headline); if descriptor.builtIn { StatusPill(text: String(localized: "Built in"), color: .green) } }
                    Text(descriptor.provider).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(text: state.installed ? String(localized: "Installed") : String(localized: "Not installed"), color: state.installed ? .green : .orange)
            }
            if state.installed {
                HStack(spacing: 7) {
                    Label(sourceLabel(state.source), systemImage: sourceIcon(state.source))
                    if !state.version.isEmpty { Text("·"); Text(versionLabel(state.version)) }
                }.font(.caption).foregroundStyle(.secondary)
            }
            if !state.error.isEmpty { Text(state.error).font(.caption).foregroundStyle(.red) }
            if !descriptor.builtIn && descriptor.id != "hermes" {
                HStack {
                    if state.installed {
                        Button("Check update") { Task { await checkUpdate(descriptor) } }.buttonStyle(.bordered).disabled(workingID != nil)
                        Button("Remove", role: .destructive) { deleteCandidate = descriptor }.buttonStyle(.bordered).disabled(workingID != nil)
                    } else {
                        Button("Install") { Task { await install(descriptor) } }.buttonStyle(.borderedProminent).disabled(workingID != nil)
                    }
                    if workingID == descriptor.id { ProgressView().controlSize(.small) }
                }
            }
        }.padding(.vertical, 6)
    }

    private func status(for id: String) -> AgentRuntimeStatus {
        if let current = statuses.first(where: { $0.id == id }) { return current }
        if let tool = tools.first(where: { $0.id == id }) { return AgentRuntimeStatus(["id": tool.id, "installed": tool.installed, "source": tool.source, "path": tool.path, "version": tool.version, "error": tool.error]) }
        return AgentRuntimeStatus(["id": id, "installed": id == "ekko-agent", "source": id == "ekko-agent" ? "built-in" : "not-installed"])
    }
    private func sourceLabel(_ source: String) -> String { source == "managed-runtime" ? String(localized: "Managed runtime") : (source == "built-in" ? String(localized: "Built in") : String(localized: "Local CLI")) }
    private func sourceIcon(_ source: String) -> String { source == "managed-runtime" ? "shippingbox.fill" : (source == "built-in" ? "checkmark.seal.fill" : "terminal.fill") }
    private func versionLabel(_ raw: String) -> String { raw.lowercased().hasPrefix("v") ? raw : "v\(raw)" }
    private func load() async { loading = true; do { async let statusRequest = store.api.agentStatuses(); async let toolRequest = store.api.codingAgents(); statuses = try await statusRequest; tools = try await toolRequest } catch { store.errorMessage = error.localizedDescription }; loading = false }
    private func install(_ descriptor: AgentDescriptor) async { workingID = descriptor.id; do { _ = try await store.api.installCodingAgent(descriptor.id); await load(); store.notify(String(localized: "Agent installed")) } catch { store.errorMessage = error.localizedDescription }; workingID = nil }
    private func checkUpdate(_ descriptor: AgentDescriptor) async { workingID = descriptor.id; do { let result = try await store.api.checkCodingAgentUpdate(descriptor.id); if result.available { store.notify("Update available: \(result.latest)") } else { store.notify(String(localized: "Agent is up to date")) }; await load() } catch { store.errorMessage = error.localizedDescription }; workingID = nil }
    private func remove(_ descriptor: AgentDescriptor) async { deleteCandidate = nil; workingID = descriptor.id; do { try await store.api.deleteCodingAgent(descriptor.id); await load() } catch { store.errorMessage = error.localizedDescription }; workingID = nil }
}

private struct AgentDescriptor: Identifiable {
    let id: String
    let name: String
    let provider: String
    let symbol: String
    let tint: Color
    let builtIn: Bool
}
