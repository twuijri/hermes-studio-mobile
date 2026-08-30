import SwiftUI
import CoreImage.CIFilterBuiltins

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
                NavigationLink { StudioFilesView() } label: { AgentToolRow(icon: "folder.fill", color: .blue, title: "Files", detail: "Browse and edit Studio workspace files") }
                NavigationLink { StudioLogsView() } label: { AgentToolRow(icon: "doc.text.magnifyingglass", color: .gray, title: "Logs", detail: "Inspect Studio logs and errors") }
                NavigationLink { StudioConnectionsView() } label: { AgentToolRow(icon: "point.3.connected.trianglepath.dotted", color: .green, title: "Connections", detail: "App Relay, paired apps and devices") }
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
                NavigationLink { EkkoHubView() } label: { AgentToolRow(icon: "sparkles", color: .purple, title: "Ekko", detail: "Built-in agent configuration, memory and tools") }
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

struct StudioFilesView: View {
    @EnvironmentObject private var store: AppStore
    let path: String
    @State private var files: [StudioFileItem] = []; @State private var loading = true; @State private var importing = false; @State private var newFolder = false; @State private var folderName = ""; @State private var actionFile: StudioFileItem?; @State private var actionName = ""
    init(path: String = "") { self.path = path }
    var body: some View { List { if loading { ProgressView() }; ForEach(files) { file in Group { if file.isDirectory { NavigationLink { StudioFilesView(path: file.path) } label: { row(file) } } else { NavigationLink { StudioFileEditor(file: file) } label: { row(file) } } }.swipeActions { Button(role: .destructive) { Task { await delete(file) } } label: { Label("Delete", systemImage: "trash") }; Button { actionFile = file; actionName = file.path } label: { Label("More", systemImage: "ellipsis") } } } }.navigationTitle(path.isEmpty ? "Files" : URL(fileURLWithPath: path).lastPathComponent).overlay { if !loading && files.isEmpty { ContentUnavailableView("Empty folder", systemImage: "folder") } }.task { await load() }.refreshable { await load() }.toolbar { ToolbarItemGroup(placement: .topBarTrailing) { Button { newFolder = true } label: { Image(systemName: "folder.badge.plus") }; Button { importing = true } label: { Image(systemName: "square.and.arrow.down") } } }.fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in if case let .success(urls) = result { Task { await upload(urls) } } }.alert("New folder", isPresented: $newFolder) { TextField("Name", text: $folderName); Button("Create") { Task { await mkdir() } }; Button("Cancel", role: .cancel) {} }.confirmationDialog("File actions", isPresented: Binding(get: { actionFile != nil }, set: { if !$0 { actionFile = nil } })) { if let file = actionFile { Button("Rename or move") { actionName = file.path; renamePrompt = true }; Button("Copy") { actionName = file.path + "-copy"; copyPrompt = true }; if let url = store.api.studioFileURL(file.path, profile: store.selectedProfile) { Link("Open externally", destination: url) } }; Button("Cancel", role: .cancel) {} }.alert("Rename or move", isPresented: $renamePrompt) { TextField("Path", text: $actionName); Button("Save") { Task { await rename() } }; Button("Cancel", role: .cancel) {} }.alert("Copy file", isPresented: $copyPrompt) { TextField("Destination path", text: $actionName); Button("Copy") { Task { await copy() } }; Button("Cancel", role: .cancel) {} } }
    @State private var renamePrompt = false; @State private var copyPrompt = false
    private func row(_ file: StudioFileItem) -> some View { HStack { Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill").foregroundStyle(file.isDirectory ? .blue : .secondary); VStack(alignment: .leading) { Text(file.name); if !file.isDirectory { Text(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file)).font(.caption).foregroundStyle(.secondary) } } } }
    private func joined(_ name: String) -> String { path.isEmpty ? name : "\(path)/\(name)" }
    private func load() async { loading = true; do { files = try await store.api.studioFiles(path: path, profile: store.selectedProfile) } catch { store.errorMessage = error.localizedDescription }; loading = false }
    private func mkdir() async { do { try await store.api.mkdirStudioFile(joined(folderName), profile: store.selectedProfile); folderName = ""; await load() } catch { store.errorMessage = error.localizedDescription } }
    private func delete(_ file: StudioFileItem) async { do { try await store.api.deleteStudioFile(file.path, recursive: file.isDirectory, profile: store.selectedProfile); await load() } catch { store.errorMessage = error.localizedDescription } }
    private func rename() async { guard let file = actionFile else { return }; do { try await store.api.renameStudioFile(file.path, to: actionName, profile: store.selectedProfile); actionFile = nil; await load() } catch { store.errorMessage = error.localizedDescription } }
    private func copy() async { guard let file = actionFile else { return }; do { try await store.api.copyStudioFile(file.path, to: actionName, profile: store.selectedProfile); actionFile = nil; await load() } catch { store.errorMessage = error.localizedDescription } }
    private func upload(_ urls: [URL]) async { for url in urls { let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }; if let data = try? Data(contentsOf: url) { try? await store.api.uploadStudioFile(data: data, name: url.lastPathComponent, mime: "application/octet-stream", path: path, profile: store.selectedProfile) } }; await load() }
}

private struct StudioFileEditor: View { @EnvironmentObject var store: AppStore; let file: StudioFileItem; @State var content = ""; @State var loading = true
    var body: some View { TextEditor(text: $content).font(.body.monospaced()).padding(6).navigationTitle(file.name).navigationBarTitleDisplayMode(.inline).overlay { if loading { ProgressView() } }.task { do { content = try await store.api.readStudioFile(file.path, profile: store.selectedProfile) } catch { store.errorMessage = error.localizedDescription }; loading = false }.toolbar { ToolbarItemGroup(placement: .topBarTrailing) { if let url = store.api.studioFileURL(file.path, profile: store.selectedProfile) { ShareLink(item: url) { Image(systemName: "square.and.arrow.up") } }; Button("Save") { Task { do { try await store.api.writeStudioFile(file.path, content: content, profile: store.selectedProfile); store.notify(String(localized: "File saved")) } catch { store.errorMessage = error.localizedDescription } } } } } }
}

struct StudioLogsView: View { @EnvironmentObject var store: AppStore; @State var files: [StudioLogFile] = []
    var body: some View { List(files) { file in NavigationLink { StudioLogDetail(file: file) } label: { VStack(alignment: .leading) { Text(file.name).font(.headline); HStack { Text(file.size); Text("·"); Text(file.modified) }.font(.caption).foregroundStyle(.secondary) } } }.navigationTitle("Logs").task { files = (try? await store.api.logFiles()) ?? files }.refreshable { files = (try? await store.api.logFiles()) ?? files } }
}
private struct StudioLogDetail: View { @EnvironmentObject var store: AppStore; let file: StudioLogFile; @State var entries: [StudioLogEntry] = []; @State var search = ""; @State var level = ""
    var body: some View { List { SearchBar(text: $search); Picker("Level", selection: $level) { Text("All").tag(""); ForEach(["error","warn","info","debug"], id: \.self) { Text($0.capitalized).tag($0) } }.pickerStyle(.segmented); ForEach(entries) { entry in VStack(alignment: .leading, spacing: 4) { HStack { StatusPill(text: entry.level, color: entry.level == "error" ? .red : (entry.level == "warn" ? .orange : .blue)); Text(entry.timestamp).font(.caption2).foregroundStyle(.secondary) }; Text(entry.message.nilIfEmpty ?? entry.raw).font(.caption.monospaced()).textSelection(.enabled) } } }.navigationTitle(file.name).task(id: "\(search)|\(level)") { try? await Task.sleep(for: .milliseconds(250)); entries = (try? await store.api.logEntries(file.name, text: search, level: level)) ?? entries } }
}

struct StudioConnectionsView: View {
    @EnvironmentObject var store: AppStore
    @State var relay: AppRelayInfo?; @State var connections: [AppConnectionItem] = []; @State var devices: [StudioDevice] = []; @State var peers: [PeerConnection] = []; @State var authorization = ""; @State var pairingPayload = ""; @State var manualURL = ""; @State var requesting = false; @State var loading = true
    var body: some View {
        List {
            Section("App Relay") {
                LabeledContent("Status") { StatusPill(text: relay?.connected == true ? String(localized: "Connected") : String(localized: "Disconnected"), color: relay?.connected == true ? .green : .gray) }
                Picker("Route", selection: Binding(get: { relay?.route ?? "official" }, set: { route in Task { relay = try? await store.api.appRelay("route", method: "PUT", body: ["route": route]) } })) { Text("Official").tag("official"); Text("Cloudflare").tag("cloudflare") }
                if let code = relay?.pairingCode.nilIfEmpty { LabeledContent("Pairing code", value: code).textSelection(.enabled) }
                if let code = relay?.pairingCode.nilIfEmpty { QRImageView(value: code).frame(maxWidth: .infinity) }
                Button(relay?.connected == true ? "Disconnect relay" : "Connect relay") { Task { relay = try? await store.api.appRelay(relay?.connected == true ? "disconnect" : "connect", method: "POST") } }
                Button("Refresh pairing code") { Task { relay = try? await store.api.appRelay("pairing-code", method: "POST") } }
            }
            Section("App connections") {
                Button("Create LAN pairing code") { Task { let value = try? await store.api.appAuthorization(cloud: false); authorization = value?.string("authorization_code", "qr_payload") ?? "" } }
                Button("Create cloud matching code") { Task { let value = try? await store.api.appAuthorization(cloud: true); authorization = value?.string("matching_code", "qr_payload") ?? "" } }
                if !authorization.isEmpty { Text(authorization).font(.title3.monospaced()).textSelection(.enabled) }
                if !authorization.isEmpty { QRImageView(value: authorization).frame(maxWidth: .infinity) }
                ForEach(connections) { item in HStack { VStack(alignment: .leading) { Text(item.name); Text("\(item.model) · \(item.type)").font(.caption).foregroundStyle(.secondary) }; Spacer(); StatusPill(text: item.online ? String(localized: "Online") : String(localized: "Offline"), color: item.online ? .green : .gray) }.swipeActions { Button(role: .destructive) { Task { try? await store.api.deleteAppConnection(item.id); await load() } } label: { Label("Delete", systemImage: "trash") } } }
            }
            Section("Studio devices") {
                Button("Scan devices") { Task { devices = (try? await store.api.devices(scan: true)) ?? devices } }
                Button("Show pairing QR") { Task { let value = try? await store.api.devicePairingLink(); pairingPayload = value?.string("link", "code") ?? "" } }
                Button("Request device by URL") { requesting = true }
                if !pairingPayload.isEmpty { QRImageView(value: pairingPayload); Text(pairingPayload).font(.caption.monospaced()).textSelection(.enabled) }
                ForEach(devices) { device in VStack(alignment: .leading, spacing: 6) { HStack { Text(device.name).font(.headline); Spacer(); StatusPill(text: device.online ? String(localized: "Online") : String(localized: "Offline"), color: device.online ? .green : .gray) }; Text(device.url).font(.caption.monospaced()).foregroundStyle(.secondary); HStack { if device.inbound == "pending" { Button("Approve") { Task { try? await store.api.deviceAction(device.id, action: "approve"); await load() } }; Button("Reject") { Task { try? await store.api.deviceAction(device.id, action: "reject"); await load() } } }; if device.inbound == "blocked" { Button("Unblock") { Task { try? await store.api.deviceAction(device.id, action: "unblock"); await load() } } } else { Button("Block") { Task { try? await store.api.deviceAction(device.id, action: "block"); await load() } } }; if device.inbound == "approved" || device.outbound == "approved" { Button("Connect") { Task { try? await store.api.deviceAction(device.id, action: "connect"); await load() } } } } } }
            }
            Section("Peer connections") {
                ForEach(peers) { peer in HStack { VStack(alignment: .leading) { Text(peer.name); Text(peer.url).font(.caption.monospaced()).foregroundStyle(.secondary) }; Spacer(); Button("Disconnect", role: .destructive) { Task { try? await store.api.disconnectPeer(peer.id); await load() } } } }
            }
        }.navigationTitle("Connections").overlay { if loading { ProgressView() } }.task { await load() }.refreshable { await load() }.alert("Request device by URL", isPresented: $requesting) { TextField("https://device.local", text: $manualURL); Button("Request") { Task { try? await store.api.requestDevice(url: manualURL); await load() } }; Button("Cancel", role: .cancel) {} }
    }
    private func load() async { loading = true; async let relayRequest = store.api.appRelay(); async let connectionsRequest = store.api.appConnections(); async let devicesRequest = store.api.devices(); async let peersRequest = store.api.peerConnections(); relay = try? await relayRequest; connections = (try? await connectionsRequest) ?? connections; devices = (try? await devicesRequest) ?? devices; peers = (try? await peersRequest) ?? peers; loading = false }
}

struct QRImageView: View {
    let value: String
    private var image: UIImage? { let filter = CIFilter.qrCodeGenerator(); filter.message = Data(value.utf8); filter.correctionLevel = "M"; guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)), let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }; return UIImage(cgImage: cg) }
    var body: some View { Group { if let image { Image(uiImage: image).interpolation(.none).resizable().scaledToFit().frame(width: 190, height: 190).padding(10).background(.white, in: RoundedRectangle(cornerRadius: 14)) } } }
}
