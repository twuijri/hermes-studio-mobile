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
                NavigationLink { GlobalAgentView() } label: { AgentToolRow(icon: "globe.desk.fill", color: .mint, title: "Global Agent", detail: "Global sessions and remote agent control") }
                NavigationLink { WorkflowsView() } label: { AgentToolRow(icon: "point.3.connected.trianglepath.dotted", color: .orange, title: "Workflows", detail: "Run automations and review their history") }
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

struct GlobalAgentView: View {
    @EnvironmentObject private var store: AppStore
    @State private var sessions: [SessionSummary] = []
    @State private var loading = true
    private var freshSession: SessionSummary { SessionSummary(["id": UUID().uuidString, "title": String(localized: "New global session"), "profile": store.selectedProfile, "source": "global_agent", "agent": "ekko-agent"], profile: store.selectedProfile) }
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Global Agent", systemImage: "globe.desk.fill").font(.headline)
                    Text("Control Studio's always-available global agent and return to its sessions from any device.").font(.subheadline).foregroundStyle(.secondary)
                    NavigationLink { ConversationView(session: freshSession) } label: { Label("Start global session", systemImage: "plus.bubble.fill") }.buttonStyle(.borderedProminent)
                }.padding(.vertical, 6)
            }
            Section("Global sessions") {
                if loading { ProgressView() }
                else if sessions.isEmpty { ContentUnavailableView("No global sessions", systemImage: "globe") }
                ForEach(sessions) { session in
                    NavigationLink { ConversationView(session: session) } label: {
                        VStack(alignment: .leading, spacing: 4) { Text(session.title).font(.headline); HStack { Text(session.profile); if session.messageCount > 0 { Text("· \(session.messageCount) messages") } }.font(.caption).foregroundStyle(.secondary); if !session.preview.isEmpty { Text(session.preview).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) } }
                    }
                }
            }
        }.listStyle(.insetGrouped).navigationTitle("Global Agent").refreshable { await load() }.task { await load() }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") } } }
    }
    private func load() async { loading = true; do { sessions = try await store.api.sessions(profile: store.selectedProfile).filter { $0.source == "global_agent" } } catch { store.errorMessage = error.localizedDescription }; loading = false }
}

struct WorkflowsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var workflows: [WorkflowItem] = []
    @State private var loading = true
    var body: some View {
        List {
            if loading && workflows.isEmpty { ProgressView("Loading workflows…") }
            else if workflows.isEmpty { ContentUnavailableView("No workflows", systemImage: "point.3.connected.trianglepath.dotted", description: Text("Create workflow definitions in Studio, then run and monitor them here.")) }
            ForEach(workflows) { workflow in
                NavigationLink { WorkflowDetailView(workflow: workflow) } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "point.3.connected.trianglepath.dotted").font(.title3).foregroundStyle(.orange).frame(width: 42, height: 42).background(.orange.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) { Text(workflow.name).font(.headline); HStack { Text(workflow.profile); Text("·"); Text("\(workflow.nodeCount) nodes") }.font(.caption).foregroundStyle(.secondary); if !workflow.workspace.isEmpty { Text(workflow.workspace).font(.caption2).foregroundStyle(.tertiary).lineLimit(1) } }
                    }
                }
            }
        }.listStyle(.insetGrouped).navigationTitle("Workflows").refreshable { await load() }.task { await load() }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") } } }
    }
    private func load() async { loading = true; do { workflows = try await store.api.workflows(profile: store.selectedProfile) } catch { store.errorMessage = error.localizedDescription }; loading = false }
}

private struct WorkflowDetailView: View {
    @EnvironmentObject private var store: AppStore
    let workflow: WorkflowItem
    @State private var runs: [WorkflowRun] = []
    @State private var loading = true
    @State private var running = false
    @State private var showRunPrompt = false
    @State private var runInput = ""
    var body: some View {
        List {
            Section {
                LabeledContent("Profile", value: workflow.profile)
                LabeledContent("Nodes", value: "\(workflow.nodeCount)")
                if !workflow.workspace.isEmpty { LabeledContent("Workspace", value: workflow.workspace) }
                Button { showRunPrompt = true } label: { Label("Run workflow", systemImage: "play.fill") }.disabled(running)
            }
            Section("Run history") {
                if loading { ProgressView() }
                else if runs.isEmpty { Text("No runs yet").foregroundStyle(.secondary) }
                ForEach(runs) { run in WorkflowRunRow(workflow: workflow, run: run, reload: load) }
            }
        }.navigationTitle(workflow.name).navigationBarTitleDisplayMode(.inline).refreshable { await load() }.task { await load() }
        .alert("Run workflow", isPresented: $showRunPrompt) { TextField("Optional input", text: $runInput, axis: .vertical); Button("Run") { Task { await start() } }; Button("Cancel", role: .cancel) {} } message: { Text("Provide optional input for the workflow's start nodes.") }
    }
    private func load() async { loading = true; do { runs = try await store.api.workflowRuns(workflow.id) } catch { store.errorMessage = error.localizedDescription }; loading = false }
    private func start() async { running = true; do { try await store.api.runWorkflow(workflow.id, input: runInput); store.notify(String(localized: "Workflow started")); try? await Task.sleep(for: .milliseconds(500)); await load() } catch { store.errorMessage = error.localizedDescription }; running = false }
}

private struct WorkflowRunRow: View {
    @EnvironmentObject private var store: AppStore
    let workflow: WorkflowItem
    let run: WorkflowRun
    let reload: () async -> Void
    @State private var expanded = false
    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            ForEach(run.nodes) { node in
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(node.nodeID).font(.subheadline.weight(.semibold)); Spacer(); StatusPill(text: node.status, color: node.status == "completed" ? .green : (node.status == "blocked" ? .orange : .blue)) }
                    if !node.agent.isEmpty { Text(AgentIdentity.displayName(for: node.agent)).font(.caption).foregroundStyle(.secondary) }
                    if !node.error.isEmpty { Text(node.error).font(.caption).foregroundStyle(.red) }
                    if node.status == "blocked" {
                        HStack { Button("Approve") { Task { await approve(node, true) } }.buttonStyle(.borderedProminent); Button("Reject", role: .destructive) { Task { await approve(node, false) } }.buttonStyle(.bordered) }
                    }
                }.padding(.vertical, 4)
            }
            if run.status == "running" || run.status == "queued" { Button("Stop run", role: .destructive) { Task { await stop() } } }
            Button("Delete run", role: .destructive) { Task { await delete() } }
        } label: {
            HStack { VStack(alignment: .leading) { Text("Run \(run.id.prefix(8))").font(.headline); Text("\(run.nodes.count) nodes").font(.caption).foregroundStyle(.secondary) }; Spacer(); StatusPill(text: run.status, color: run.status == "completed" ? .green : (run.status == "failed" ? .red : .blue)) }
        }
    }
    private func stop() async { do { try await store.api.stopWorkflow(workflow.id, runID: run.id); await reload() } catch { store.errorMessage = error.localizedDescription } }
    private func delete() async { do { try await store.api.deleteWorkflowRun(workflow.id, runID: run.id); await reload() } catch { store.errorMessage = error.localizedDescription } }
    private func approve(_ node: WorkflowRunNode, _ approved: Bool) async { do { try await store.api.approveWorkflowNode(workflow.id, runID: run.id, node: node, approved: approved); await reload() } catch { store.errorMessage = error.localizedDescription } }
}
