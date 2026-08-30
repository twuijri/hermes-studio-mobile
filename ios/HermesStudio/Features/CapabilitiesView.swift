import SwiftUI

struct SkillsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var skills: [SkillItem] = []
    @State private var pendingWrites: [PendingSkillWrite] = []
    @State private var resolvingWrite = ""
    @State private var search = ""; @State private var loading = true
    var body: some View {
        List {
            Section { SearchBar(text: $search).listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden) }
            if !pendingWrites.isEmpty {
                Section("Pending skill approvals (\(pendingWrites.count))") {
                    ForEach(pendingWrites) { pending in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(pending.summary.isEmpty ? pending.id : pending.summary).font(.headline)
                            Text([pending.action, pending.origin].filter { !$0.isEmpty }.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                            HStack {
                                Button("Approve") { Task { await resolve(pending, approve: true) } }.buttonStyle(.borderedProminent).tint(.green)
                                Button("Reject", role: .destructive) { Task { await resolve(pending, approve: false) } }.buttonStyle(.bordered)
                            }.disabled(!resolvingWrite.isEmpty)
                        }.padding(.vertical, 4)
                    }
                }
            }
            ForEach(categories, id: \.self) { category in
                Section(category.capitalized) {
                    ForEach(filtered.filter { $0.category == category }) { skill in
                        NavigationLink { SkillEditorView(skill: skill) { await load() } } label: {
                            HStack(spacing: 12) { Image(systemName: skill.pinned ? "pin.fill" : "square.stack.3d.up.fill").foregroundStyle(skill.enabled ? HermesTheme.purple : .gray).frame(width: 36, height: 36).background((skill.enabled ? HermesTheme.purple : .gray).opacity(0.11), in: RoundedRectangle(cornerRadius: 10)); VStack(alignment: .leading, spacing: 3) { Text(skill.name).font(.headline); if !skill.description.isEmpty { Text(skill.description).font(.caption).foregroundStyle(.secondary).lineLimit(2) } }; Spacer(); if !skill.enabled { StatusPill(text: String(localized: "Off"), color: .gray) } }.padding(.vertical, 3)
                        }.swipeActions(edge: .leading) { Button { Task { await pin(skill) } } label: { Label(skill.pinned ? "Unpin" : "Pin", systemImage: "pin") }.tint(.orange); Button { Task { await toggle(skill) } } label: { Label(skill.enabled ? "Disable" : "Enable", systemImage: "power") }.tint(skill.enabled ? .gray : .green) }
                    }
                }
            }
        }.listStyle(.insetGrouped).navigationTitle("Skills").overlay { if loading { ProgressView() } }.refreshable { await load() }.task(id: store.selectedProfile) { await load() }
    }
    private var filtered: [SkillItem] { search.isEmpty ? skills : skills.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.description.localizedCaseInsensitiveContains(search) } }
    private var categories: [String] { Array(Set(filtered.map(\.category))).sorted() }
    private func load() async { loading = true; do { async let skillsRequest = store.api.skills(profile: store.selectedProfile); async let approvalsRequest = store.api.pendingSkillWrites(profile: store.selectedProfile); skills = try await skillsRequest; pendingWrites = try await approvalsRequest } catch { store.errorMessage = error.localizedDescription }; loading = false }
    private func resolve(_ pending: PendingSkillWrite, approve: Bool) async { resolvingWrite = pending.id; do { try await store.api.resolvePendingSkillWrite(pending.id, approve: approve, profile: store.selectedProfile); await load() } catch { store.errorMessage = error.localizedDescription }; resolvingWrite = "" }
    private func toggle(_ skill: SkillItem) async { do { try await store.api.toggleSkill(skill, profile: store.selectedProfile); await load() } catch { store.errorMessage = error.localizedDescription } }
    private func pin(_ skill: SkillItem) async { do { try await store.api.pinSkill(skill, profile: store.selectedProfile); await load() } catch { store.errorMessage = error.localizedDescription } }
}

private struct SkillEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State var skill: SkillItem
    let onChange: () async -> Void
    @State private var loaded = false; @State private var saving = false; @State private var deleteConfirm = false
    var body: some View {
        VStack(spacing: 0) {
            HStack { StatusPill(text: skill.category.capitalized, color: .blue); Spacer(); Toggle("Enabled", isOn: Binding(get: { skill.enabled }, set: { _ in Task { try? await store.api.toggleSkill(skill, profile: store.selectedProfile); skill.enabled.toggle() } })).labelsHidden() }.padding()
            TextEditor(text: $skill.content).font(.system(.body, design: .monospaced)).padding(10).scrollContentBackground(.hidden).background(Color(uiColor: .secondarySystemBackground)).overlay { if !loaded { ProgressView() } }
        }.navigationTitle(skill.name).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItemGroup(placement: .topBarTrailing) { Button { skill.pinned.toggle(); Task { try? await store.api.pinSkill(skill, profile: store.selectedProfile) } } label: { Image(systemName: skill.pinned ? "pin.fill" : "pin") }; Button("Save") { Task { await save() } }.disabled(saving) } }
            .task { do { skill = try await store.api.skill(category: skill.category, name: skill.name, profile: store.selectedProfile) } catch { store.errorMessage = error.localizedDescription }; loaded = true }
            .safeAreaInset(edge: .bottom) { Button("Delete skill", role: .destructive) { deleteConfirm = true }.font(.footnote).padding(8) }
            .alert("Delete skill?", isPresented: $deleteConfirm) { Button("Delete", role: .destructive) { Task { try? await store.api.deleteSkill(skill, profile: store.selectedProfile); await onChange(); dismiss() } }; Button("Cancel", role: .cancel) {} }
    }
    private func save() async { saving = true; do { try await store.api.saveSkill(skill, profile: store.selectedProfile); await onChange(); store.notify(String(localized: "Skill saved")) } catch { store.errorMessage = error.localizedDescription }; saving = false }
}

struct PluginsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var plugins: [PluginItem] = []; @State private var loading = true
    var body: some View {
        List(plugins) { plugin in
            HStack(spacing: 13) { Image(systemName: "puzzlepiece.extension.fill").foregroundStyle(plugin.enabled ? HermesTheme.purple : .gray).frame(width: 42, height: 42).background((plugin.enabled ? HermesTheme.purple : .gray).opacity(0.12), in: RoundedRectangle(cornerRadius: 12)); VStack(alignment: .leading, spacing: 4) { Text(plugin.name).font(.headline); Text(plugin.description).font(.caption).foregroundStyle(.secondary).lineLimit(2); if !plugin.version.isEmpty { Text("v\(plugin.version)").font(.caption2.monospaced()).foregroundStyle(.tertiary) } }; Spacer(); Toggle("", isOn: Binding(get: { plugin.enabled }, set: { value in Task { await set(plugin, value) } })).labelsHidden() }.padding(.vertical, 4)
        }.listStyle(.insetGrouped).navigationTitle("Plugins").overlay { if loading { ProgressView() } }.refreshable { await load() }.task { await load() }
    }
    private func load() async { loading = true; do { plugins = try await store.api.plugins() } catch { store.errorMessage = error.localizedDescription }; loading = false }
    private func set(_ plugin: PluginItem, _ value: Bool) async { do { try await store.api.setPlugin(plugin, enabled: value); await load() } catch { store.errorMessage = error.localizedDescription } }
}

struct MCPView: View {
    @EnvironmentObject private var store: AppStore
    @State private var servers: [MCPServer] = []; @State private var loading = true; @State private var creating = false; @State private var editing: MCPServer?
    var body: some View {
        Group { if !loading && servers.isEmpty { EmptyState(icon: "server.rack", title: "No MCP servers", detail: "Connect tools using a local command or remote URL.") } else { List(servers) { server in Button { editing = server } label: { HStack(spacing: 12) { Image(systemName: server.url.isEmpty ? "terminal.fill" : "network").foregroundStyle(.cyan).frame(width: 42, height: 42).background(.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 12)); VStack(alignment: .leading, spacing: 4) { Text(server.name).font(.headline).foregroundStyle(.primary); Text(server.url.nilIfEmpty ?? ([server.command] + server.arguments).joined(separator: " ")).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(2); if !server.tools.isEmpty { Text("\(server.tools.count) tools").font(.caption2).foregroundStyle(.secondary) } }; Spacer(); StatusPill(text: server.enabled ? String(localized: "On") : String(localized: "Off"), color: server.enabled ? .green : .gray) }.padding(.vertical, 4) }.buttonStyle(.plain).swipeActions { Button(role: .destructive) { Task { await delete(server) } } label: { Label("Delete", systemImage: "trash") } } }.listStyle(.insetGrouped) } }
            .navigationTitle("MCP").toolbar { ToolbarItemGroup(placement: .topBarTrailing) { Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }; Button { creating = true } label: { Image(systemName: "plus") } } }.overlay { if loading { ProgressView() } }.refreshable { await load() }.task { await load() }.sheet(isPresented: $creating) { MCPEditor(server: nil) { await load() } }.sheet(item: $editing) { MCPEditor(server: $0) { await load() } }
    }
    private func load() async { loading = true; do { servers = try await store.api.mcpServers() } catch { store.errorMessage = error.localizedDescription }; loading = false }
    private func delete(_ server: MCPServer) async { do { try await store.api.deleteMCP(server.name); await load() } catch { store.errorMessage = error.localizedDescription } }
}

private struct MCPEditor: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let server: MCPServer?; let onSave: () async -> Void
    @State private var name = ""; @State private var mode = "command"; @State private var command = ""; @State private var arguments = ""; @State private var url = ""; @State private var enabled = true; @State private var saving = false; @State private var testResult: String?
    var body: some View {
        NavigationStack { Form { Section("Server") { TextField("Name", text: $name).disabled(server != nil); Picker("Connection", selection: $mode) { Text("Command").tag("command"); Text("Remote URL").tag("url") }.pickerStyle(.segmented); if mode == "command" { TextField("Command", text: $command).textInputAutocapitalization(.never); TextField("Arguments (one per line)", text: $arguments, axis: .vertical).font(.body.monospaced()).lineLimit(3...8) } else { TextField("https://…", text: $url).keyboardType(.URL).textInputAutocapitalization(.never) }; Toggle("Enabled", isOn: $enabled) }; if server != nil { Section { Button("Test connection") { Task { await test() } }; Button("Reload tools") { Task { try? await store.api.reloadMCP(name); store.notify(String(localized: "MCP reloaded")) } }; if let testResult { Text(testResult).font(.caption.monospaced()) } } } }.navigationTitle(server == nil ? "Add MCP server" : "Edit MCP server").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(name.isEmpty || saving) } }.onAppear { guard let server else { return }; name = server.name; command = server.command; arguments = server.arguments.joined(separator: "\n"); url = server.url; enabled = server.enabled; mode = url.isEmpty ? "command" : "url" } }
    }
    private func save() async { saving = true; do { try await store.api.saveMCP(name: name, command: mode == "command" ? command : "", arguments: arguments.split(separator: "\n").map(String.init), url: mode == "url" ? url : "", enabled: enabled, existing: server != nil); await onSave(); dismiss() } catch { store.errorMessage = error.localizedDescription }; saving = false }
    private func test() async { do { let result = try await store.api.testMCP(name); testResult = result.string("message", "status").nilIfEmpty ?? String(localized: "Connection successful") } catch { testResult = error.localizedDescription } }
}

struct PetsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var pets: [Pet] = []; @State private var active: Set<String> = []; @State private var loading = true
    var body: some View {
        ScrollView { LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], spacing: 12) { ForEach(pets) { pet in Button { Task { await toggle(pet) } } label: { VStack(spacing: 11) { Text(pet.emoji).font(.system(size: 44)); Text(pet.name).font(.headline).foregroundStyle(.primary); Text(pet.species).font(.caption).foregroundStyle(.secondary); Text(pet.description).font(.caption2).foregroundStyle(.secondary).lineLimit(3); StatusPill(text: active.contains(pet.id) ? String(localized: "Active") : String(localized: "Adopt"), color: active.contains(pet.id) ? .green : HermesTheme.purple) }.frame(maxWidth: .infinity).padding(14).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 19)).overlay(RoundedRectangle(cornerRadius: 19).stroke(active.contains(pet.id) ? Color.green.opacity(0.4) : .clear)) }.buttonStyle(.plain) } }.padding() }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("Pets").overlay { if loading { ProgressView() } }.refreshable { await load() }.task { await load() }
    }
    private func load() async {
        loading = true
        async let manifestRequest = store.api.petManifest()
        async let activeRequest = store.api.activePets()
        do {
            pets = try await manifestRequest
            let activePets = try await activeRequest
            active = Set(activePets.map(\.id))
        } catch { store.errorMessage = error.localizedDescription }
        loading = false
    }
    private func toggle(_ pet: Pet) async {
        do {
            if active.contains(pet.id) {
                try await store.api.setPet(pet.id, profile: store.selectedProfile, active: false)
                active.removeAll()
            } else {
                try await store.api.adoptPet(pet.id, profile: store.selectedProfile)
                active = [pet.id]
            }
        } catch { store.errorMessage = error.localizedDescription }
    }
}

struct ModelsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var models: [ModelOption] = []
    @State private var search = ""
    @State private var selected = ""
    @State private var loading = true

    var body: some View {
        List {
            Section { NavigationLink { ProvidersView() } label: { AgentToolRow(icon: "network", color: .blue, title: "Providers", detail: "Status, connection tests and model refresh") } }
            Section {
                SearchBar(text: $search)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
            ForEach(groupedProviders, id: \.self) { provider in
                Section(provider.isEmpty ? "Models" : provider) {
                    ForEach(filtered.filter { $0.provider == provider }) { model in
                        Button { Task { await select(model) } } label: {
                            HStack {
                                Image(systemName: model.id == selected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(model.id == selected ? HermesTheme.purple : .secondary)
                                VStack(alignment: .leading) {
                                    Text(model.name).foregroundStyle(.primary)
                                    Text(model.id).font(.caption2.monospaced()).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Models")
        .overlay { if loading { ProgressView() } }
        .task(id: store.selectedProfile) { await load() }
    }
    private var filtered: [ModelOption] { search.isEmpty ? models : models.filter { $0.name.localizedCaseInsensitiveContains(search) || $0.id.localizedCaseInsensitiveContains(search) } }
    private var groupedProviders: [String] { Array(Set(filtered.map(\.provider))).sorted() }
    private func load() async {
        loading = true
        async let modelRequest = store.api.models(profile: store.selectedProfile)
        async let configRequest = store.api.config(profile: store.selectedProfile)
        do {
            models = try await modelRequest
            let config = try await configRequest
            selected = config.object("model").string("default")
        } catch { store.errorMessage = error.localizedDescription }
        loading = false
    }
    private func select(_ model: ModelOption) async { do { try await store.api.setDefaultModel(profile: store.selectedProfile, model: model.id, provider: model.provider.nilIfEmpty); selected = model.id; store.notify(String(localized: "Default model updated")) } catch { store.errorMessage = error.localizedDescription } }
}

struct ProvidersView: View {
    @EnvironmentObject private var store: AppStore
    @State private var providers: [ProviderSummary] = []; @State private var working: String?
    var body: some View { List { ForEach(providers) { provider in VStack(alignment: .leading, spacing: 9) { HStack { VStack(alignment: .leading) { Text(provider.label).font(.headline); Text(provider.id).font(.caption.monospaced()).foregroundStyle(.secondary) }; Spacer(); StatusPill(text: provider.credentialConfigured ? String(localized: "Configured") : String(localized: "Needs key"), color: provider.credentialConfigured ? .green : .orange) }; if !provider.baseURL.isEmpty { Text(provider.baseURL).font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(1) }; Text("\(provider.models.count) models").font(.caption).foregroundStyle(.secondary); HStack { Button("Test") { Task { await test(provider) } }.buttonStyle(.bordered); if provider.refreshable { Button("Refresh models") { Task { await refresh(provider) } }.buttonStyle(.bordered) }; if working == provider.id { ProgressView().controlSize(.small) } } }.padding(.vertical, 5) } }.navigationTitle("Providers").refreshable { await load() }.task { await load() }.toolbar { Button("Refresh all") { Task { try? await store.api.refreshProviderCache(); await load() } } } }
    private func load() async { providers = (try? await store.api.providers(profile: store.selectedProfile)) ?? providers }
    private func test(_ item: ProviderSummary) async { working = item.id; do { let result = try await store.api.testProvider(item.id); store.notify(result.bool("success") ? String(localized: "Connection successful") : result.string("error").nilIfEmpty ?? String(localized: "Connection failed")) } catch { store.errorMessage = error.localizedDescription }; working = nil }
    private func refresh(_ item: ProviderSummary) async { working = item.id; do { let result = try await store.api.refreshProviderModels(item.id); if result.bool("requires_confirmation") { _ = try await store.api.refreshProviderModels(item.id, confirm: true) }; await load() } catch { store.errorMessage = error.localizedDescription }; working = nil }
}

struct EkkoSkillsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var items: [EkkoSkillItem] = []; @State private var search = ""; @State private var selected: EkkoSkillItem?; @State private var importing = false
    var body: some View { List { SearchBar(text: $search); ForEach(items) { item in Button { Task { selected = try? await store.api.ekkoSkill(item.name) } } label: { HStack { VStack(alignment: .leading) { Text(item.name).font(.headline).foregroundStyle(.primary); Text(item.description).font(.caption).foregroundStyle(.secondary).lineLimit(2) }; Spacer(); Toggle("", isOn: Binding(get: { item.enabled }, set: { value in Task { try? await store.api.setEkkoSkill(item.name, enabled: value); await load() } } )).labelsHidden() } } } }.navigationTitle("Ekko skills").task(id: search) { try? await Task.sleep(for: .milliseconds(250)); await load() }.sheet(item: $selected) { EkkoSkillDetailView(item: $0) { await load() } }.toolbar { Button { importing = true } label: { Image(systemName: "square.and.arrow.down") } }.fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in if case let .success(url) = result { Task { await importSkill(url) } } } }
    private func load() async { items = (try? await store.api.ekkoSkills(query: search)) ?? items }
    private func importSkill(_ url: URL) async { let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }; do { try await store.api.importEkkoSkill(data: Data(contentsOf: url), name: url.lastPathComponent); await load() } catch { store.errorMessage = error.localizedDescription } }
}

private struct EkkoSkillDetailView: View { @EnvironmentObject var store: AppStore; @Environment(\.dismiss) var dismiss; @State var item: EkkoSkillItem; @State var files: [JSON] = []; let saved: () async -> Void
    var body: some View { NavigationStack { Form { Section("Skill") { LabeledContent("Category", value: item.category); LabeledContent("Source", value: item.source); TextEditor(text: $item.content).frame(minHeight: 240).font(.body.monospaced()) }; if !files.isEmpty { Section("Files") { ForEach(Array(files.enumerated()), id: \.offset) { _, file in Label(file.string("path", "name"), systemImage: file.bool("directory") ? "folder" : "doc") } } } }.navigationTitle(item.name).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { try? await store.api.saveEkkoSkill(item); await saved(); dismiss() } } } }.task { files = (try? await store.api.ekkoSkillFiles(item.name)) ?? [] } } }
}

struct EkkoMCPView: View {
    @EnvironmentObject private var store: AppStore
    @State private var servers: [EkkoMCPItem] = []; @State private var editing: EkkoMCPItem?; @State private var creating = false
    var body: some View { List { ForEach(servers) { server in Button { editing = server } label: { HStack { VStack(alignment: .leading) { Text(server.name).font(.headline).foregroundStyle(.primary); Text(server.url.nilIfEmpty ?? ([server.command] + server.arguments).joined(separator: " ")).font(.caption.monospaced()).foregroundStyle(.secondary) }; Spacer(); StatusPill(text: server.enabled ? String(localized: "On") : String(localized: "Off"), color: server.enabled ? .green : .gray) } }.swipeActions { Button(role: .destructive) { Task { try? await store.api.deleteEkkoMCP(server.name); await load() } } label: { Label("Delete", systemImage: "trash") } } } }.navigationTitle("Ekko MCP").task { await load() }.refreshable { await load() }.toolbar { Button { creating = true } label: { Image(systemName: "plus") } }.sheet(isPresented: $creating) { EkkoMCPEditor(server: nil) { await load() } }.sheet(item: $editing) { EkkoMCPEditor(server: $0) { await load() } } }
    private func load() async { servers = (try? await store.api.ekkoMCPServers()) ?? servers }
}

private struct EkkoMCPEditor: View { @EnvironmentObject var store: AppStore; @Environment(\.dismiss) var dismiss; let server: EkkoMCPItem?; let saved: () async -> Void; @State var name = ""; @State var command = ""; @State var args = ""; @State var url = ""; @State var enabled = true; @State var testResult = ""
    var body: some View { NavigationStack { Form { TextField("Name", text: $name).disabled(server != nil); TextField("Remote URL", text: $url).keyboardType(.URL); if url.isEmpty { TextField("Command", text: $command); TextField("Arguments", text: $args, axis: .vertical) }; Toggle("Enabled", isOn: $enabled); if server != nil { Button("Test connection") { Task { let tools = try? await store.api.testEkkoMCP(name); testResult = "\(tools?.count ?? 0) tools" } }; if !testResult.isEmpty { Text(testResult) } } }.navigationTitle(server == nil ? "Add Ekko MCP" : "Edit Ekko MCP").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { let item = EkkoMCPItem(["name": name, "config": ["enabled": enabled, "command": command, "args": args.split(separator: " ").map(String.init), "url": url]]); try? await store.api.saveEkkoMCP(item, existing: server != nil); await saved(); dismiss() } }.disabled(name.isEmpty) } }.onAppear { if let server { name = server.name; command = server.command; args = server.arguments.joined(separator: " "); url = server.url; enabled = server.enabled } } } }
}
