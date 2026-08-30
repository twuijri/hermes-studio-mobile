import SwiftUI
import CoreImage.CIFilterBuiltins
import UniformTypeIdentifiers

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
                NavigationLink { JourneyView() } label: { AgentToolRow(icon: "point.3.filled.connected.trianglepath.dotted", color: .indigo, title: "Journey", detail: "Explore connected skills and memories") }
                NavigationLink { SkillUsageView() } label: { AgentToolRow(icon: "chart.bar.xaxis", color: .cyan, title: "Skills Usage", detail: "See skill loads, edits and trends") }
                NavigationLink { CronJobsView() } label: { AgentToolRow(icon: "calendar.badge.clock", color: .blue, title: "Scheduled Jobs", detail: "Automations, schedules and delivery") }
                NavigationLink { KanbanView() } label: { AgentToolRow(icon: "rectangle.3.group", color: .orange, title: "Kanban", detail: "Plan work with a touch-first board") }
                NavigationLink { ChannelsView() } label: { AgentToolRow(icon: "antenna.radiowaves.left.and.right", color: .green, title: "Channels", detail: "Connect every messaging platform") }
                NavigationLink { WebhooksView() } label: { AgentToolRow(icon: "arrow.triangle.branch", color: .orange, title: "Webhooks", detail: "Deliver Studio chat events") }
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
                NavigationLink { RuntimeVersionsView() } label: { AgentToolRow(icon: "shippingbox.and.arrow.backward.fill", color: .blue, title: "Runtime Versions", detail: "Download, activate and restart Studio") }
                NavigationLink { ThemeStudioView() } label: { AgentToolRow(icon: "paintpalette.fill", color: .pink, title: "Appearance", detail: "Sync palette, text and background") }
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

struct JourneyView: View {
    @EnvironmentObject private var store: AppStore
    @State private var journey: JourneyGraph?; @State private var mode = 0; @State private var query = ""; @State private var loading = true
    private var nodes: [JourneyNode] { journey?.nodes.filter { query.isEmpty || $0.label.localizedCaseInsensitiveContains(query) || $0.category.localizedCaseInsensitiveContains(query) } ?? [] }
    var body: some View { VStack { Picker("View", selection: $mode) { Text("Graph").tag(0); Text("Structured").tag(1) }.pickerStyle(.segmented).padding(.horizontal); if loading { Spacer(); ProgressView(); Spacer() } else if mode == 0 { JourneyGraphCanvas(nodes: nodes, edges: journey?.edges ?? []).padding() } else { List { if let journey { Section("Overview") { LabeledContent("Profile", value: journey.profile); LabeledContent("Nodes", value: "\(journey.nodes.count)"); LabeledContent("Connections", value: "\(journey.edges.count)") }; ForEach(Dictionary(grouping: nodes, by: { $0.category.nilIfEmpty ?? $0.kind }).keys.sorted(), id: \.self) { category in Section(category.capitalized) { ForEach(nodes.filter { ($0.category.nilIfEmpty ?? $0.kind) == category }) { node in HStack { Image(systemName: node.kind == "memory" ? "brain.head.profile" : "sparkles"); VStack(alignment: .leading) { Text(node.label); Text("\(node.kind) · \(node.useCount) uses").font(.caption).foregroundStyle(.secondary) }; Spacer(); if node.pinned { Image(systemName: "pin.fill") } } } } } } } } }.navigationTitle("Journey").searchable(text: $query).refreshable { await load() }.task { await load() } }
    private func load() async { loading = true; do { journey = try await store.api.journey() } catch { store.errorMessage = error.localizedDescription }; loading = false }
}

private struct JourneyGraphCanvas: View {
    let nodes: [JourneyNode]; let edges: [JourneyEdge]
    var body: some View { GeometryReader { geo in ZStack { Canvas { context, size in let points = positions(size); for edge in edges { if let a = points[edge.source], let b = points[edge.target] { var path = Path(); path.move(to: a); path.addLine(to: b); context.stroke(path, with: .color(.secondary.opacity(0.28)), lineWidth: 1) } } }; ForEach(Array(nodes.prefix(36).enumerated()), id: \.element.id) { index, node in let p = point(index, count: min(nodes.count, 36), size: geo.size); VStack(spacing: 3) { Circle().fill(node.kind == "memory" ? Color.purple : Color.blue).frame(width: node.pinned ? 22 : 16, height: node.pinned ? 22 : 16); Text(node.label).font(.caption2).lineLimit(2).frame(width: 82) }.position(p) } }.accessibilityElement(children: .contain) }.overlay { if nodes.isEmpty { ContentUnavailableView("No journey data", systemImage: "point.3.connected.trianglepath.dotted") } } }
    private func point(_ index: Int, count: Int, size: CGSize) -> CGPoint { let angle = Double(index) / Double(max(count, 1)) * .pi * 2; let ring = CGFloat(0.35 + Double(index % 3) * 0.13); return CGPoint(x: size.width / 2 + CGFloat(cos(angle)) * size.width * ring, y: size.height / 2 + CGFloat(sin(angle)) * size.height * ring) }
    private func positions(_ size: CGSize) -> [String: CGPoint] { Dictionary(uniqueKeysWithValues: Array(nodes.prefix(36).enumerated()).map { ($0.element.id, point($0.offset, count: min(nodes.count, 36), size: size)) }) }
}

struct SkillUsageView: View {
    @EnvironmentObject private var store: AppStore
    @State private var days = 7; @State private var stats: SkillUsageStats?
    var body: some View { List { Picker("Period", selection: $days) { Text("7 days").tag(7); Text("30 days").tag(30); Text("90 days").tag(90) }.pickerStyle(.segmented); if let stats { Section("Summary") { HStack { UsageMetric(title: "Loads", value: stats.totalLoads); UsageMetric(title: "Edits", value: stats.totalEdits); UsageMetric(title: "Skills", value: stats.distinct) } }; Section("Top skills") { ForEach(stats.top) { row in VStack(alignment: .leading, spacing: 7) { HStack { Text(row.id).font(.headline); Spacer(); Text("\(row.total)").font(.headline.monospacedDigit()) }; ProgressView(value: min(row.percentage, 100), total: 100).tint(.indigo); Text("\(row.views) loads · \(row.edits) edits").font(.caption).foregroundStyle(.secondary) } } }; Section("Daily activity") { ForEach(stats.daily.indices, id: \.self) { i in let day = stats.daily[i]; LabeledContent(day.string("date"), value: "\(day.int("total_count"))") } } } else { ProgressView() } }.navigationTitle("Skills Usage").task(id: days) { await load() }.refreshable { await load() } }
    private func load() async { do { stats = try await store.api.skillUsage(days: days) } catch { store.errorMessage = error.localizedDescription } }
}
private struct UsageMetric: View { let title: LocalizedStringKey; let value: Int; var body: some View { VStack { Text("\(value)").font(.title2.bold().monospacedDigit()); Text(title).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity) } }

struct WebhooksView: View {
    @EnvironmentObject private var store: AppStore
    @State private var endpoints: [WebhookEndpoint] = []; @State private var editing: WebhookEndpoint?; @State private var creating = false; @State private var target = ""; @State private var events: [JSON] = []
    var body: some View { List { Section("Endpoints") { ForEach(endpoints) { item in Button { editing = item } label: { VStack(alignment: .leading, spacing: 4) { HStack { Text(item.name).font(.headline); Spacer(); StatusPill(text: item.runtime.string("state").nilIfEmpty ?? (item.enabled ? "enabled" : "disabled"), color: item.runtime.string("state") == "success" ? .green : .secondary) }; Text(item.url).font(.caption).foregroundStyle(.secondary).lineLimit(1); Text(item.events.joined(separator: " · ")).font(.caption2).foregroundStyle(.tertiary).lineLimit(2) } }.buttonStyle(.plain).swipeActions { Button(role: .destructive) { Task { await delete(item) } } label: { Label("Delete", systemImage: "trash") }; Button { Task { await test(item) } } label: { Label("Test", systemImage: "bolt") }.tint(.blue) } } }; Section("Local test target") { Text(target).font(.caption).textSelection(.enabled); Button("Clear events", role: .destructive) { Task { try? await store.api.clearLocalWebhookEvents(); await loadLocal() } }; ForEach(events.indices, id: \.self) { i in VStack(alignment: .leading) { Text(events[i].string("event")).font(.headline); Text(events[i].string("received_at")).font(.caption).foregroundStyle(.secondary); Text(events[i].string("event_id")).font(.caption2).textSelection(.enabled) } } } }.navigationTitle("Webhooks").toolbar { Button { creating = true } label: { Image(systemName: "plus") } }.sheet(isPresented: $creating) { WebhookEditor(item: nil) { await load() } }.sheet(item: $editing) { item in WebhookEditor(item: item) { await load() } }.task { await load(); await loadLocal() }.refreshable { await load(); await loadLocal() } }
    private func load() async { do { endpoints = try await store.api.webhookEndpoints() } catch { store.errorMessage = error.localizedDescription } }
    private func loadLocal() async { target = (try? await store.api.localWebhookTarget().string("url")) ?? ""; events = (try? await store.api.localWebhookEvents()) ?? [] }
    private func delete(_ item: WebhookEndpoint) async { do { try await store.api.deleteWebhook(item.id); await load() } catch { store.errorMessage = error.localizedDescription } }
    private func test(_ item: WebhookEndpoint) async { do { let result = try await store.api.testWebhook(item.id); store.notify(result.bool("ok") ? String(localized: "Webhook delivered") : result.string("error").nilIfEmpty ?? String(localized: "Webhook failed")); await load() } catch { store.errorMessage = error.localizedDescription } }
}

private struct WebhookEditor: View {
    @EnvironmentObject private var store: AppStore; @Environment(\.dismiss) private var dismiss
    let item: WebhookEndpoint?; let reload: () async -> Void
    @State private var name = ""; @State private var url = ""; @State private var secret = ""; @State private var enabled = true; @State private var includeContent = false; @State private var includeUser = false; @State private var privateNetwork = false; @State private var retries = 3; @State private var selected: Set<String> = ["chat.run.completed", "chat.run.failed"]
    private let allEvents = ["chat.message.created", "chat.run.queued", "chat.run.started", "chat.tool.started", "chat.tool.completed", "chat.tool.failed", "chat.approval.requested", "chat.approval.resolved", "chat.clarification.requested", "chat.clarification.resolved", "chat.run.completed", "chat.run.failed"]
    var body: some View { NavigationStack { Form { Section("Destination") { TextField("Name", text: $name); TextField("HTTPS URL", text: $url).textInputAutocapitalization(.never).keyboardType(.URL); SecureField("Signing secret", text: $secret); Toggle("Enabled", isOn: $enabled); Stepper("Maximum retries: \(retries)", value: $retries, in: 0...10) }; Section("Payload") { Toggle("Include assistant content", isOn: $includeContent); Toggle("Include user content", isOn: $includeUser); Toggle("Allow private network", isOn: $privateNetwork) }; Section("Events") { ForEach(allEvents, id: \.self) { event in Button { if selected.contains(event) { selected.remove(event) } else { selected.insert(event) } } label: { HStack { Text(event); Spacer(); if selected.contains(event) { Image(systemName: "checkmark") } } }.foregroundStyle(.primary) } } }.navigationTitle(item == nil ? "New webhook" : "Edit webhook").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(name.isEmpty || url.isEmpty || selected.isEmpty) } }.onAppear { if let item { name = item.name; url = item.url; enabled = item.enabled; includeContent = item.includeContent; includeUser = item.includeUserContent; privateNetwork = item.privateNetwork; retries = item.retries; selected = Set(item.events) } } } }
    private func save() async { do { try await store.api.saveWebhook(item, name: name, url: url, secret: secret, events: selected.sorted(), profiles: item?.profiles ?? [], enabled: enabled, includeContent: includeContent, includeUserContent: includeUser, privateNetwork: privateNetwork, retries: retries); await reload(); dismiss() } catch { store.errorMessage = error.localizedDescription } }
}

struct RuntimeVersionsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var status: RuntimeVersionStatus?; @State private var jobs: [JSON] = []; @State private var source = "cf"; @State private var working = ""
    var body: some View { List { if let status { Section("Active") { LabeledContent("Platform", value: status.platform); LabeledContent("Hermes runtime", value: status.activeRuntime); LabeledContent("Studio Web UI", value: status.activeWebUI); if !status.runtimeError.isEmpty { Text(status.runtimeError).foregroundStyle(.red) }; Button("Restart Studio") { Task { await restart() } }.disabled(!working.isEmpty) }; versions(title: "Hermes runtimes", kind: "runtime", installed: status.installedRuntime, remote: status.remoteRuntime, active: status.activeRuntime); versions(title: "Studio Web UI", kind: "webui", installed: status.installedWebUI, remote: status.remoteWebUI, active: status.activeWebUI); if !jobs.isEmpty { Section("Downloads") { ForEach(jobs.indices, id: \.self) { index in let job = jobs[index]; VStack(alignment: .leading) { HStack { Text(job.string("version")).font(.headline); Spacer(); Text(job.string("status")).foregroundStyle(job.string("status") == "failed" ? Color.red : Color.secondary) }; ProgressView(value: job.double("percent"), total: 100); Text(job.string("message", "error")).font(.caption).foregroundStyle(.secondary) } } } } } else { ProgressView() } }.navigationTitle("Runtime Versions").toolbar { ToolbarItem(placement: .topBarTrailing) { Picker("Source", selection: $source) { Text("Cloudflare").tag("cf"); Text("GitHub").tag("github") } } }.task { await load() }.refreshable { await load() } }
    private func versions(title: LocalizedStringKey, kind: String, installed: [JSON], remote: [String], active: String) -> some View { Section(title) { ForEach(installed.indices, id: \.self) { i in let row = installed[i], version = row.string("version"); HStack { VStack(alignment: .leading) { Text(version).font(.headline); Text(row.string("directory")).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }; Spacer(); if version == active || row.bool("active") { StatusPill(text: "Active", color: .green) } else { Menu { Button("Activate") { Task { await activate(version, kind) } }; Button("Delete", role: .destructive) { Task { await delete(version, kind) } } } label: { Image(systemName: "ellipsis.circle") } } } }; ForEach(remote.filter { version in !installed.contains(where: { $0.string("version") == version }) }, id: \.self) { version in HStack { Text(version); Spacer(); Button("Download") { Task { await download(version, kind) } }.disabled(!working.isEmpty) } } } }
    private func load() async { do { status = try await store.api.runtimeVersions(); jobs = try await store.api.runtimeJobs() } catch { store.errorMessage = error.localizedDescription } }
    private func download(_ version: String, _ kind: String) async { working = version; do { try await store.api.downloadVersion(version, kind: kind, source: source); store.notify(String(localized: "Download started")); await load() } catch { store.errorMessage = error.localizedDescription }; working = "" }
    private func activate(_ version: String, _ kind: String) async { working = version; do { try await store.api.activateVersion(version, kind: kind); await load() } catch { store.errorMessage = error.localizedDescription }; working = "" }
    private func delete(_ version: String, _ kind: String) async { do { try await store.api.deleteVersion(version, kind: kind); await load() } catch { store.errorMessage = error.localizedDescription } }
    private func restart() async { working = "restart"; do { try await store.api.restartVersionedWebUI(); store.notify(String(localized: "Restart requested")) } catch { store.errorMessage = error.localizedDescription }; working = "" }
}

struct ThemeStudioView: View {
    @EnvironmentObject private var store: AppStore
    @State private var settings: ThemeSettings?; @State private var fontSize = 16.0; @State private var textColor = ""; @State private var accentColor = ""; @State private var importing = false; @State private var saving = false
    private let palette = ["#7C3AED", "#2563EB", "#0891B2", "#059669", "#D97706", "#DC2626", "#DB2777"]
    var body: some View { Form { Section("Typography") { Slider(value: $fontSize, in: 12...24, step: 1); LabeledContent("Font size", value: "\(Int(fontSize)) pt"); TextField("Text color (hex)", text: $textColor).textInputAutocapitalization(.characters) }; Section("Accent palette") { LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) { ForEach(palette, id: \.self) { hex in Button { accentColor = hex } label: { Circle().fill(Color(hex: hex) ?? .accentColor).frame(width: 34, height: 34).overlay { if accentColor.uppercased() == hex { Image(systemName: "checkmark").foregroundStyle(.white).font(.caption.bold()) } } }.buttonStyle(.plain) } }; TextField("Accent color (hex)", text: $accentColor).textInputAutocapitalization(.characters) }; Section("Background") { if let settings, !settings.background.isEmpty { LabeledContent("Current", value: settings.background.string("name")); Button("Remove background", role: .destructive) { Task { await removeBackground() } } }; Button("Choose background image") { importing = true } }; Section { Button("Save appearance") { Task { await save() } }.disabled(saving) } }.navigationTitle("Appearance").task { await load() }.fileImporter(isPresented: $importing, allowedContentTypes: [.image]) { result in if case let .success(url) = result { Task { await upload(url) } } } }
    private func load() async { do { let value = try await store.api.themeSettings(); settings = value; fontSize = value.fontSize == 0 ? 16 : value.fontSize; textColor = value.textColor; accentColor = value.accentColor } catch { store.errorMessage = error.localizedDescription } }
    private func save() async { saving = true; do { settings = try await store.api.saveTheme(fontSize: fontSize, textColor: textColor.nilIfEmpty, accentColor: accentColor.nilIfEmpty); store.notify(String(localized: "Appearance saved")) } catch { store.errorMessage = error.localizedDescription }; saving = false }
    private func upload(_ url: URL) async { let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }; do { let data = try Data(contentsOf: url); try await store.api.uploadThemeBackground(data: data, name: url.lastPathComponent, mime: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "image/jpeg"); await load() } catch { store.errorMessage = error.localizedDescription } }
    private func removeBackground() async { do { try await store.api.deleteThemeBackground(); await load() } catch { store.errorMessage = error.localizedDescription } }
}

private extension Color { init?(hex: String) { let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")); guard value.count == 6, let number = Int(value, radix: 16) else { return nil }; self.init(red: Double((number >> 16) & 255) / 255, green: Double((number >> 8) & 255) / 255, blue: Double(number & 255) / 255) } }

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
    @State private var editing: WorkflowItem?; @State private var creating = false; @State private var importing = false; @State private var importPreview: JSON = [:]; @State private var importToken = ""; @State private var showingImport = false
    @State private var selectedIDs: Set<String> = []
    var body: some View {
        List(selection: $selectedIDs) {
            if loading && workflows.isEmpty { ProgressView("Loading workflows…") }
            else if workflows.isEmpty { ContentUnavailableView("No workflows", systemImage: "point.3.connected.trianglepath.dotted", description: Text("Create workflow definitions in Studio, then run and monitor them here.")) }
            ForEach(workflows) { workflow in
                NavigationLink { WorkflowDetailView(workflow: workflow) } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "point.3.connected.trianglepath.dotted").font(.title3).foregroundStyle(.orange).frame(width: 42, height: 42).background(.orange.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) { Text(workflow.name).font(.headline); HStack { Text(workflow.profile); Text("·"); Text("\(workflow.nodeCount) nodes") }.font(.caption).foregroundStyle(.secondary); if !workflow.workspace.isEmpty { Text(workflow.workspace).font(.caption2).foregroundStyle(.tertiary).lineLimit(1) } }
                    }
                }
                .tag(workflow.id)
                .swipeActions { Button(role: .destructive) { Task { await delete(workflow) } } label: { Label("Delete", systemImage: "trash") }; Button { editing = workflow } label: { Label("Edit", systemImage: "pencil") }.tint(.blue) }
            }
        }.listStyle(.insetGrouped).navigationTitle("Workflows").refreshable { await load() }.task { await load() }
        .toolbar { ToolbarItemGroup(placement: .topBarTrailing) { if !selectedIDs.isEmpty { Button(role: .destructive) { Task { await batchDelete() } } label: { Image(systemName: "trash") } }; EditButton(); Button { importing = true } label: { Image(systemName: "square.and.arrow.down") }; Button { creating = true } label: { Image(systemName: "plus") }; Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") } } }
        .sheet(isPresented: $creating) { WorkflowEditor(workflow: nil) { await load() } }
        .sheet(item: $editing) { item in WorkflowEditor(workflow: item) { await load() } }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json, .plainText]) { result in if case let .success(url) = result { Task { await previewImport(url) } } }
        .alert("Import workflow?", isPresented: $showingImport) { Button("Import") { Task { await confirmImport() } }; Button("Cancel", role: .cancel) { Task { await cancelImport() } } } message: { Text("\(importPreview.object("summary").string("name")) · \(importPreview.object("summary").int("nodes")) nodes") }
    }
    private func load() async { loading = true; do { workflows = try await store.api.workflows(profile: store.selectedProfile) } catch { store.errorMessage = error.localizedDescription }; loading = false }
    private func delete(_ workflow: WorkflowItem) async { do { try await store.api.deleteWorkflow(workflow.id); await load() } catch { store.errorMessage = error.localizedDescription } }
    private func batchDelete() async { do { _ = try await store.api.batchDeleteWorkflows(Array(selectedIDs)); selectedIDs = []; await load() } catch { store.errorMessage = error.localizedDescription } }
    private func previewImport(_ url: URL) async { let access = url.startAccessingSecurityScopedResource(); defer { if access { url.stopAccessingSecurityScopedResource() } }; do { let document = try String(contentsOf: url); importPreview = try await store.api.previewWorkflowImport(document, profile: store.selectedProfile); importToken = importPreview.string("token"); showingImport = !importToken.isEmpty } catch { store.errorMessage = error.localizedDescription } }
    private func confirmImport() async { do { try await store.api.confirmWorkflowImport(token: importToken, profile: store.selectedProfile); importToken = ""; await load() } catch { store.errorMessage = error.localizedDescription } }
    private func cancelImport() async { try? await store.api.cancelWorkflowImport(token: importToken, profile: store.selectedProfile); importToken = "" }
}

private struct WorkflowEditor: View {
    @EnvironmentObject private var store: AppStore; @Environment(\.dismiss) private var dismiss
    let workflow: WorkflowItem?; let reload: () async -> Void
    @State private var name = ""; @State private var profile = ""; @State private var workspace = ""; @State private var nodes = "[]"; @State private var edges = "[]"; @State private var error = ""
    var body: some View { NavigationStack { Form { Section("Definition") { TextField("Name", text: $name); Picker("Profile", selection: $profile) { ForEach(store.profiles) { Text($0.name).tag($0.name) } }; TextField("Workspace path", text: $workspace) }; Section("Nodes JSON") { TextEditor(text: $nodes).font(.caption.monospaced()).frame(minHeight: 180) }; Section("Edges JSON") { TextEditor(text: $edges).font(.caption.monospaced()).frame(minHeight: 120) }; if !error.isEmpty { Text(error).foregroundStyle(.red) } }.navigationTitle(workflow == nil ? "New workflow" : "Edit workflow").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(name.isEmpty) } }.onAppear { profile = workflow?.profile.nilIfEmpty ?? store.selectedProfile; name = workflow?.name ?? ""; workspace = workflow?.workspace ?? ""; nodes = encode(workflow?.nodes ?? []); edges = encode(workflow?.edges ?? []) } } }
    private func encode(_ value: Any) -> String { guard JSONSerialization.isValidJSONObject(value), let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) else { return "[]" }; return String(data: data, encoding: .utf8) ?? "[]" }
    private func decode(_ text: String) throws -> [JSON] { guard let data = text.data(using: .utf8), let rows = try JSONSerialization.jsonObject(with: data) as? [JSON] else { throw HermesError.server(String(localized: "Definition must be a JSON array")) }; return rows }
    private func save() async { do { _ = try await store.api.saveWorkflow(id: workflow?.id, name: name, profile: profile, workspace: workspace.nilIfEmpty, nodes: try decode(nodes), edges: try decode(edges), viewport: workflow?.viewport ?? [:]); await reload(); dismiss() } catch let failure { error = failure.localizedDescription } }
}

private struct WorkflowDetailView: View {
    @EnvironmentObject private var store: AppStore
    let workflow: WorkflowItem
    @State private var runs: [WorkflowRun] = []
    @State private var loading = true
    @State private var running = false
    @State private var showRunPrompt = false
    @State private var runInput = ""
    @State private var schedules: [WorkflowSchedule] = []; @State private var editingSchedule: WorkflowSchedule?; @State private var newSchedule = false; @State private var exportURL: URL?
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
            Section("Schedules") { ForEach(schedules) { schedule in Button { editingSchedule = schedule } label: { HStack { VStack(alignment: .leading) { Text(schedule.schedule).font(.headline); Text(schedule.timezone).font(.caption).foregroundStyle(.secondary) }; Spacer(); StatusPill(text: schedule.enabled ? "Enabled" : "Disabled", color: schedule.enabled ? .green : .secondary) } }.buttonStyle(.plain).swipeActions { Button(role: .destructive) { Task { await deleteSchedule(schedule) } } label: { Label("Delete", systemImage: "trash") } } }; Button("Add schedule") { newSchedule = true } }
        }.navigationTitle(workflow.name).navigationBarTitleDisplayMode(.inline).refreshable { await load() }.task { await load() }
        .alert("Run workflow", isPresented: $showRunPrompt) { TextField("Optional input", text: $runInput, axis: .vertical); Button("Run") { Task { await start() } }; Button("Cancel", role: .cancel) {} } message: { Text("Provide optional input for the workflow's start nodes.") }
        .sheet(isPresented: $newSchedule) { WorkflowScheduleEditor(workflowID: workflow.id, schedule: nil) { await load() } }
        .sheet(item: $editingSchedule) { item in WorkflowScheduleEditor(workflowID: workflow.id, schedule: item) { await load() } }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { if let exportURL { ShareLink(item: exportURL) { Image(systemName: "square.and.arrow.up") } } else { Button { Task { await exportDefinition() } } label: { Image(systemName: "square.and.arrow.up") } } } }
    }
    private func load() async { loading = true; do { runs = try await store.api.workflowRuns(workflow.id); schedules = try await store.api.workflowSchedules(workflow.id) } catch { store.errorMessage = error.localizedDescription }; loading = false }
    private func start() async { running = true; do { try await store.api.runWorkflow(workflow.id, input: runInput); store.notify(String(localized: "Workflow started")); try? await Task.sleep(for: .milliseconds(500)); await load() } catch { store.errorMessage = error.localizedDescription }; running = false }
    private func deleteSchedule(_ schedule: WorkflowSchedule) async { do { try await store.api.deleteWorkflowSchedule(workflowID: workflow.id, scheduleID: schedule.id); await load() } catch { store.errorMessage = error.localizedDescription } }
    private func exportDefinition() async { do { let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(workflow.name.replacingOccurrences(of: "/", with: "-"))-workflow.json"); try await store.api.exportWorkflow(workflow.id).write(to: url, options: .atomic); exportURL = url } catch { store.errorMessage = error.localizedDescription } }
}

private struct WorkflowScheduleEditor: View {
    @EnvironmentObject private var store: AppStore; @Environment(\.dismiss) private var dismiss
    let workflowID: String; let schedule: WorkflowSchedule?; let reload: () async -> Void
    @State private var expression = "0 9 * * *"; @State private var timezone = TimeZone.current.identifier; @State private var enabled = true; @State private var input = ""
    var body: some View { NavigationStack { Form { TextField("Cron schedule", text: $expression).textInputAutocapitalization(.never); TextField("Timezone", text: $timezone).textInputAutocapitalization(.never); Toggle("Enabled", isOn: $enabled); TextField("Optional input", text: $input, axis: .vertical) }.navigationTitle(schedule == nil ? "New schedule" : "Edit schedule").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(expression.isEmpty || timezone.isEmpty) } }.onAppear { if let schedule { expression = schedule.schedule; timezone = schedule.timezone; enabled = schedule.enabled; input = schedule.input } } } }
    private func save() async { do { try await store.api.saveWorkflowSchedule(workflowID: workflowID, scheduleID: schedule?.id, schedule: expression, timezone: timezone, enabled: enabled, input: input); await reload(); dismiss() } catch { store.errorMessage = error.localizedDescription } }
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
                    Button("Rerun from node") { Task { await rerun(node) } }.buttonStyle(.bordered)
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
    private func rerun(_ node: WorkflowRunNode) async { do { try await store.api.rerunWorkflow(workflow.id, runID: run.id, nodeID: node.nodeID); await reload() } catch { store.errorMessage = error.localizedDescription } }
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
