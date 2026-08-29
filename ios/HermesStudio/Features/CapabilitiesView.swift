import SwiftUI

struct SkillsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var skills: [SkillItem] = []
    @State private var search = ""; @State private var loading = true
    var body: some View {
        List {
            Section { SearchBar(text: $search).listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden) }
            Section("Approvals") {
                NavigationLink { StudioSectionSettings(section: .skills) } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Approve skill changes")
                            Text("Require approval before the agent creates or modifies skills.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "checkmark.shield.fill").foregroundStyle(.green) }
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
    private func load() async { loading = true; do { skills = try await store.api.skills(profile: store.selectedProfile) } catch { store.errorMessage = error.localizedDescription }; loading = false }
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
