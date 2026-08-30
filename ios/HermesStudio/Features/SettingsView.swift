import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        List {
            Section {
                NavigationLink { AccountView() } label: { HStack(spacing: 13) { ProfileAvatar(name: store.currentUser?.username ?? "Account", avatar: store.currentUser?.avatar, size: 48); VStack(alignment: .leading, spacing: 3) { Text(store.currentUser?.username ?? "Account").font(.headline); Text(store.currentUser?.role.capitalized ?? "").font(.caption).foregroundStyle(.secondary) } } }
                NavigationLink { ProfilesView() } label: { SettingsRow(icon: "person.2.fill", color: .blue, title: "Profiles", subtitle: store.selectedProfile) }
                NavigationLink { ServerView() } label: { SettingsRow(icon: "server.rack", color: .green, title: "Studio connection", subtitle: store.baseURL) }
            }
            Section("App") {
                Picker(selection: Binding(get: { store.appearance }, set: store.setAppearance)) { Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark") } label: { SettingsRow(icon: "circle.lefthalf.filled", color: .indigo, title: "Appearance") { EmptyView() } }
                Picker(selection: Binding(get: { store.language }, set: store.setLanguage)) { Text("System").tag("system"); Text("العربية").tag("ar"); Text("English").tag("en") } label: { SettingsRow(icon: "globe", color: .teal, title: "Language") { EmptyView() } }
                Picker(selection: Binding(get: { store.reasoningEffort }, set: store.setReasoning)) { Text("Default").tag(""); Text("Low").tag("low"); Text("Medium").tag("medium"); Text("High").tag("high"); Text("Extra high").tag("xhigh") } label: { SettingsRow(icon: "brain.head.profile", color: .purple, title: "Reasoning effort") { EmptyView() } }
            }
            Section {
                NavigationLink { MoreSettingsView() } label: { SettingsRow(icon: "slider.horizontal.3", color: .orange, title: "More Settings", subtitle: String(localized: "All Hermes Studio settings in one place")) }
            } footer: { Text("Agent tools stay in the Agent tab. Studio configuration is collected here to keep navigation simple.") }
            Section("About") {
                HStack { SettingsRow(icon: "app.badge.fill", color: HermesTheme.purple, title: "Hermes Studio Mobile") { Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.2.0").foregroundStyle(.secondary) } }
                Link(destination: URL(string: "https://github.com/twuijri/hermes-studio-mobile")!) { RepositorySettingsRow(title: "Hermes Studio Mobile") }.foregroundStyle(.primary)
                Link(destination: URL(string: "https://github.com/EKKOLearnAI/hermes-studio")!) { RepositorySettingsRow(title: "Hermes Studio") }.foregroundStyle(.primary)
            }
            Section { Button(role: .destructive) { store.signOut() } label: { Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right").frame(maxWidth: .infinity) } }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        // Rebuild this visible list together with the three root lists after
        // UIKit's direction transform has settled (see AppStore.setLanguage).
        .id("\(store.language)-\(store.languageRefresh)")
    }
}

private struct RepositorySettingsRow: View {
    let title: LocalizedStringKey

    var body: some View {
        HStack(spacing: 13) {
            Image("GitHubMark")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(.white)
                .padding(6)
                .frame(width: 31, height: 31)
                .background(Color.black.gradient, in: RoundedRectangle(cornerRadius: 8))
            Text(title).font(.body.weight(.medium)).lineLimit(1)
            Spacer(minLength: 8)
            Image(systemName: "arrow.up.right").foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 4)
    }
}

private struct ServerView: View {
    @EnvironmentObject private var store: AppStore
    @State private var server = ""; @State private var testing = false
    var body: some View {
        Form {
            Section {
                TextField("https://studio.example.com", text: $server).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                Button { Task { testing = true; await store.updateServer(server); testing = false } } label: { HStack { if testing { ProgressView() }; Text("Save and test connection") } }.disabled(server.isEmpty || testing)
            } header: { Text("Studio address") } footer: { Text("Use your normal Studio web address. Local HTTP servers are also supported.") }
            Section("Status") { LabeledContent("Account", value: store.currentUser?.username ?? "—"); LabeledContent("Profile", value: store.selectedProfile); LabeledContent("Connection") { StatusPill(text: String(localized: "Connected"), color: .green) } }
        }.navigationTitle("Studio connection").onAppear { server = store.baseURL }
    }
}

private struct AccountView: View {
    @EnvironmentObject private var store: AppStore
    @State private var changePassword = false; @State private var changeUsername = false; @State private var photo: PhotosPickerItem?
    var body: some View {
        List {
            Section { HStack(spacing: 15) { ProfileAvatar(name: store.currentUser?.username ?? "Account", avatar: store.currentUser?.avatar, size: 68); VStack(alignment: .leading) { Text(store.currentUser?.username ?? "").font(.title3.bold()); Text(store.currentUser?.role.capitalized ?? "").foregroundStyle(.secondary) } } }
            Section("Security") { Button { changeUsername = true } label: { SettingsRow(icon: "person.text.rectangle", color: .blue, title: "Change username") }; Button { changePassword = true } label: { SettingsRow(icon: "key.fill", color: .orange, title: "Change password") } }
            Section("Avatar") { PhotosPicker(selection: $photo, matching: .images) { SettingsRow(icon: "photo.fill", color: .purple, title: "Upload image") }.onChange(of: photo) { _, item in Task { await upload(item) } }; Button { Task { try? await store.api.resetAvatar(); store.currentUser = try? await store.api.currentUser() } } label: { SettingsRow(icon: "arrow.counterclockwise", color: .gray, title: "Reset avatar") } }
        }.navigationTitle("Account").sheet(isPresented: $changePassword) { CredentialChangeView(kind: .password) }.sheet(isPresented: $changeUsername) { CredentialChangeView(kind: .username) }
    }
    private func upload(_ item: PhotosPickerItem?) async { guard let data = try? await item?.loadTransferable(type: Data.self), let mime = item?.supportedContentTypes.first?.preferredMIMEType else { return }; do { try await store.api.updateAvatar(dataURL: "data:\(mime);base64,\(data.base64EncodedString())"); store.currentUser = try await store.api.currentUser() } catch { store.errorMessage = error.localizedDescription } }
}

private struct CredentialChangeView: View {
    enum Kind { case password, username }
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let kind: Kind
    @State private var current = ""; @State private var value = ""; @State private var confirm = ""; @State private var saving = false
    var body: some View {
        NavigationStack { Form { SecureField("Current password", text: $current); if kind == .password { SecureField("New password", text: $value); SecureField("Confirm password", text: $confirm) } else { TextField("New username", text: $value).textInputAutocapitalization(.never) } }.navigationTitle(kind == .password ? "Change password" : "Change username").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(current.isEmpty || value.isEmpty || (kind == .password && value != confirm) || saving) } } }
    }
    private func save() async { saving = true; do { if kind == .password { try await store.api.changePassword(current: current, new: value) } else { try await store.api.changeUsername(currentPassword: current, newUsername: value); store.currentUser = try await store.api.currentUser() }; store.notify(String(localized: "Account updated")); dismiss() } catch { store.errorMessage = error.localizedDescription }; saving = false }
}

struct ProfilesView: View {
    @EnvironmentObject private var store: AppStore
    @State private var creating = false; @State private var newName = ""; @State private var renaming: Profile?; @State private var renameText = ""; @State private var runtimes: [ProfileRuntime] = []
    var body: some View {
        List { ForEach(store.profiles) { profile in NavigationLink { ProfileDetailView(profile: profile) } label: { HStack(spacing: 13) { ProfileAvatar(name: profile.name, avatar: profile.avatar, size: 45); VStack(alignment: .leading, spacing: 3) { Text(profile.name).font(.headline).foregroundStyle(.primary); Text(profile.model ?? "Default model").font(.caption).foregroundStyle(.secondary); if let runtime = runtimes.first(where: { $0.id == profile.name }) { Text(runtime.bridgeRunning ? "Runtime running" : "Runtime stopped").font(.caption2).foregroundStyle(runtime.bridgeRunning ? .green : .secondary) } }; Spacer(); if profile.name == store.selectedProfile { Image(systemName: "checkmark.circle.fill").foregroundStyle(HermesTheme.purple) } }.padding(.vertical, 3) }.swipeActions(edge: .leading) { Button { renameText = profile.name; renaming = profile } label: { Label("Rename", systemImage: "pencil") }.tint(.blue); Button { Task { try? await store.api.restartProfileRuntime(profile.name); await loadRuntimes() } } label: { Label("Restart runtime", systemImage: "arrow.clockwise") }.tint(.orange) }.swipeActions(edge: .trailing) { if store.profiles.count > 1 { Button(role: .destructive) { Task { try? await store.api.deleteProfile(profile.name); await store.refreshProfiles() } } label: { Label("Delete", systemImage: "trash") } } } } }.listStyle(.insetGrouped).navigationTitle("Profiles").toolbar { Button { creating = true } label: { Image(systemName: "plus") } }.refreshable { await store.refreshProfiles(); await loadRuntimes() }.task { await loadRuntimes() }
            .alert("New profile", isPresented: $creating) { TextField("Name", text: $newName); Button("Create") { Task { do { try await store.api.createProfile(newName); await store.refreshProfiles(); newName = "" } catch { store.errorMessage = error.localizedDescription } } }; Button("Cancel", role: .cancel) {} }
            .alert("Rename profile", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) { TextField("Name", text: $renameText); Button("Save") { guard let renaming else { return }; Task { do { try await store.api.renameProfile(renaming.name, to: renameText); await store.refreshProfiles() } catch { store.errorMessage = error.localizedDescription } } }; Button("Cancel", role: .cancel) {} }
    }
    private func loadRuntimes() async { runtimes = (try? await store.api.profileRuntimes()) ?? runtimes }
}

private struct ProfileDetailView: View {
    @EnvironmentObject private var store: AppStore
    let profile: Profile
    @State private var runtime: ProfileRuntime?
    @State private var photo: PhotosPickerItem?
    @State private var importing = false
    @State private var exportedURL: URL?
    var body: some View { List {
        Section { HStack(spacing: 14) { ProfileAvatar(name: profile.name, avatar: profile.avatar, size: 64); VStack(alignment: .leading) { Text(profile.name).font(.title3.bold()); Text(profile.model ?? "Default model").foregroundStyle(.secondary) } } }
        Section("Runtime status") { LabeledContent("Bridge") { StatusPill(text: runtime?.bridgeRunning == true ? String(localized: "Running") : String(localized: "Stopped"), color: runtime?.bridgeRunning == true ? .green : .gray) }; LabeledContent("Gateway") { StatusPill(text: runtime?.gatewayRunning == true ? String(localized: "Running") : String(localized: "Stopped"), color: runtime?.gatewayRunning == true ? .green : .gray) }; if let url = runtime?.gatewayURL.nilIfEmpty { Text(url).font(.caption.monospaced()).textSelection(.enabled) }; Button("Restart runtime") { Task { try? await store.api.restartProfileRuntime(profile.name); await load() } }; Button("Restart gateway") { Task { try? await store.api.restartGateway(profile: profile.name); await load() } } }
        Section("Avatar") { PhotosPicker(selection: $photo, matching: .images) { Label("Upload profile avatar", systemImage: "photo") }.onChange(of: photo) { _, item in Task { await upload(item) } }; Button("Reset profile avatar", role: .destructive) { Task { try? await store.api.resetProfileAvatar(profile.name); await store.refreshProfiles() } } }
        Section("Backup") { Button("Export profile") { Task { await export() } }; if let exportedURL { ShareLink(item: exportedURL) { Label("Share exported archive", systemImage: "square.and.arrow.up") } }; Button("Import profile archive") { importing = true } }
    }.navigationTitle(profile.name).task { await load() }.refreshable { await load() }.fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in if case let .success(url) = result { Task { await importArchive(url) } } } }
    private func load() async { if let values = try? await store.api.profileRuntimes() { runtime = values.first { $0.id == profile.name } } }
    private func upload(_ item: PhotosPickerItem?) async { guard let data = try? await item?.loadTransferable(type: Data.self), let mime = item?.supportedContentTypes.first?.preferredMIMEType else { return }; do { try await store.api.setProfileAvatar(profile.name, dataURL: "data:\(mime);base64,\(data.base64EncodedString())"); await store.refreshProfiles() } catch { store.errorMessage = error.localizedDescription } }
    private func export() async { do { let data = try await store.api.exportProfile(profile.name); let url = FileManager.default.temporaryDirectory.appendingPathComponent("hermes-profile-\(profile.name).tar.gz"); try data.write(to: url, options: .atomic); exportedURL = url } catch { store.errorMessage = error.localizedDescription } }
    private func importArchive(_ url: URL) async { let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }; do { try await store.api.importProfile(data: Data(contentsOf: url), name: url.lastPathComponent); await store.refreshProfiles(); store.notify(String(localized: "Profile imported")) } catch { store.errorMessage = error.localizedDescription } }
}

struct EkkoHubView: View {
    var body: some View { List {
        Section("Ekko") { NavigationLink { EkkoConfigurationView() } label: { SettingsRow(icon: "slider.horizontal.3", color: .purple, title: "Configuration", subtitle: "Runtime, model, tools and delegation") } }
        Section("Knowledge") { NavigationLink { EkkoMemoryView() } label: { SettingsRow(icon: "brain", color: .orange, title: "Ekko memory") }; NavigationLink { EkkoSkillsView() } label: { SettingsRow(icon: "square.stack.3d.up", color: .indigo, title: "Ekko skills") } }
        Section("Connections") { NavigationLink { EkkoMCPView() } label: { SettingsRow(icon: "server.rack", color: .cyan, title: "Ekko MCP") } }
    }.navigationTitle("Ekko").listStyle(.insetGrouped) }
}

private struct EkkoConfigurationView: View {
    @EnvironmentObject private var store: AppStore
    @State private var root: JSON = [:]; @State private var loading = true
    var body: some View { Form { if !loading { Section("Runtime") { Stepper("Maximum steps: \(int("runtime", "maxSteps", 30))", value: intBinding("runtime", "maxSteps", 30), in: 1...500) }; Section("Model") { TextField("Default provider", text: stringBinding("model", "defaultProvider")); TextField("Default model", text: stringBinding("model", "defaultModel")); Picker("Reasoning", selection: stringBinding("model", "reasoningEffort")) { ForEach(["none", "minimal", "low", "medium", "high", "xhigh", "max"], id: \.self) { Text($0).tag($0) } } }; Section("Capabilities") { Toggle("Tools enabled", isOn: boolBinding(["tools", "enabled"], true)); Toggle("Tool approvals", isOn: boolBinding(["tools", "approvals", "enabled"], true)); Toggle("Memory enabled", isOn: boolBinding(["memory", "enabled"], true)); Toggle("Skills enabled", isOn: boolBinding(["skills", "enabled"], true)); Toggle("Background delegation", isOn: boolBinding(["delegation", "backgroundEnabled"], true)) }; Button("Save settings") { Task { await save() } } } }.navigationTitle("Ekko configuration").overlay { if loading { ProgressView() } }.task { await load() } }
    private var config: JSON { root.object("config") }
    private func value(_ path: [String]) -> Any? { var current: Any = config; for key in path { guard let next = (current as? JSON)?[key] else { return nil }; current = next }; return current }
    private func set(_ path: [String], _ value: Any) { var cfg = config; func assign(_ object: inout JSON, _ keys: ArraySlice<String>) { guard let key = keys.first else { return }; if keys.count == 1 { object[key] = value; return }; var child = object.object(key); assign(&child, keys.dropFirst()); object[key] = child }; assign(&cfg, path[...]); root["config"] = cfg }
    private func int(_ section: String, _ key: String, _ fallback: Int) -> Int { (value([section,key]) as? NSNumber)?.intValue ?? fallback }
    private func intBinding(_ section: String, _ key: String, _ fallback: Int) -> Binding<Int> { Binding(get: { int(section,key,fallback) }, set: { set([section,key], $0) }) }
    private func stringBinding(_ section: String, _ key: String) -> Binding<String> { Binding(get: { value([section,key]) as? String ?? "" }, set: { set([section,key], $0) }) }
    private func boolBinding(_ path: [String], _ fallback: Bool) -> Binding<Bool> { Binding(get: { value(path) as? Bool ?? fallback }, set: { set(path, $0) }) }
    private func load() async { loading = true; do { root = try await store.api.ekkoConfig() } catch { store.errorMessage = error.localizedDescription }; loading = false }
    private func save() async { do { try await store.api.saveEkkoConfig(config); store.notify(String(localized: "Settings saved")); await load() } catch { store.errorMessage = error.localizedDescription } }
}

private struct EkkoMemoryView: View {
    @EnvironmentObject private var store: AppStore
    @State private var items: [EkkoMemoryItem] = []; @State private var query = ""; @State private var editing: EkkoMemoryItem?
    var body: some View { List { SearchBar(text: $query); ForEach(items) { item in Button { editing = item } label: { VStack(alignment: .leading, spacing: 5) { Text(item.title.nilIfEmpty ?? item.content).font(.headline).foregroundStyle(.primary).lineLimit(2); Text(item.content).font(.caption).foregroundStyle(.secondary).lineLimit(3); StatusPill(text: item.status, color: item.status == "active" ? .green : .gray) } }.swipeActions { Button(role: .destructive) { Task { try? await store.api.deleteEkkoMemory(item); await load() } } label: { Label("Delete", systemImage: "trash") } } } }.navigationTitle("Ekko memory").task(id: query) { try? await Task.sleep(for: .milliseconds(250)); await load() }.sheet(item: $editing) { EkkoMemoryEditor(item: $0) { await load() } } }
    private func load() async { items = (try? await store.api.ekkoMemory(query: query)) ?? items }
}

private struct EkkoMemoryEditor: View { @EnvironmentObject var store: AppStore; @Environment(\.dismiss) var dismiss; @State var item: EkkoMemoryItem; let saved: () async -> Void
    var body: some View { NavigationStack { Form { TextField("Title", text: $item.title); TextField("Content", text: $item.content, axis: .vertical).lineLimit(5...15); TextField("Tags", text: Binding(get: { item.tags.joined(separator: ", ") }, set: { item.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } })) }.navigationTitle("Edit memory").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { do { try await store.api.updateEkkoMemory(item); await saved(); dismiss() } catch { store.errorMessage = error.localizedDescription } } } } } } }
}

struct MoreSettingsView: View {
    var body: some View {
        List {
            Section("Agent") { NavigationLink { StudioSectionSettings(section: .agent) } label: { SettingsRow(icon: "sparkles", color: .purple, title: "Agent") }; NavigationLink { StudioSectionSettings(section: .memory) } label: { SettingsRow(icon: "lightbulb.max.fill", color: .yellow, title: "Memory") }; NavigationLink { StudioSectionSettings(section: .compression) } label: { SettingsRow(icon: "arrow.down.right.and.arrow.up.left", color: .orange, title: "Compression") }; NavigationLink { ModelsView() } label: { SettingsRow(icon: "cpu.fill", color: .mint, title: "Models") } }
            Section("Conversation") { NavigationLink { StudioSectionSettings(section: .display) } label: { SettingsRow(icon: "rectangle.on.rectangle", color: .blue, title: "Display") }; NavigationLink { StudioSectionSettings(section: .session) } label: { SettingsRow(icon: "clock.arrow.circlepath", color: .indigo, title: "Session reset") }; NavigationLink { StudioSectionSettings(section: .approvals) } label: { SettingsRow(icon: "checkmark.shield.fill", color: .green, title: "Approvals") }; NavigationLink { StudioSectionSettings(section: .skills) } label: { SettingsRow(icon: "checkmark.shield", color: .indigo, title: "Skill approvals") }; NavigationLink { StudioSectionSettings(section: .voice) } label: { SettingsRow(icon: "waveform", color: .pink, title: "Voice") } }
            Section("Network & privacy") { NavigationLink { StudioSectionSettings(section: .proxy) } label: { SettingsRow(icon: "network", color: .teal, title: "Proxy") }; NavigationLink { StudioSectionSettings(section: .privacy) } label: { SettingsRow(icon: "hand.raised.fill", color: .red, title: "Privacy") }; NavigationLink { StudioSectionSettings(section: .gateway) } label: { SettingsRow(icon: "power", color: .green, title: "Gateway auto-start") } }
        }.listStyle(.insetGrouped).navigationTitle("More Settings")
    }
}

enum StudioSettingsSection: String {
    case display, proxy, agent, memory, compression, session, approvals, skills, privacy, voice, gateway
    var apiName: String { switch self { case .session: "sessionReset"; case .gateway: "gatewayAutoStart"; default: rawValue } }
    var title: LocalizedStringKey { switch self { case .display: "Display"; case .proxy: "Proxy"; case .agent: "Agent"; case .memory: "Memory"; case .compression: "Compression"; case .session: "Session reset"; case .approvals: "Approvals"; case .skills: "Skill approvals"; case .privacy: "Privacy"; case .voice: "Voice"; case .gateway: "Gateway auto-start" } }
    var note: LocalizedStringKey { switch self { case .display: "Choose what Studio shows while agents work."; case .proxy: "Network proxy variables used by this profile."; case .agent: "Control run limits and tool behavior."; case .memory: "Manage long-term memory and user context."; case .compression: "Keep long conversations within the model context."; case .session: "Choose when a conversation starts a fresh session."; case .approvals: "Require confirmation before sensitive actions."; case .skills: "Control approval before the agent writes or changes skills."; case .privacy: "Protect personal information sent to models."; case .voice: "Configure speech transcription and voice responses."; case .gateway: "Choose whether gateways start with Studio." } }
    var fields: [ConfigField] {
        switch self {
        case .display: [.toggle("streaming", "Stream responses", true), .toggle("compact", "Compact layout", false), .toggle("show_reasoning", "Show reasoning", true), .toggle("show_cost", "Show cost", false), .toggle("inline_diffs", "Inline diffs", true), .toggle("bell_on_complete", "Bell on completion", false), .toggle("notify_on_complete", "Completion notification", false), .number("chat_input_height", "Chat input height", 0)]
        case .proxy: [.text("HTTPS_PROXY", "HTTPS proxy"), .text("HTTP_PROXY", "HTTP proxy"), .text("ALL_PROXY", "All-protocol proxy"), .text("NO_PROXY", "Exclude hosts")]
        case .agent: [.number("max_turns", "Maximum turns", 0), .number("gateway_timeout", "Gateway timeout", 0), .number("restart_drain_timeout", "Restart drain timeout", 30), .choice("tool_use_enforcement", "Tool use", "auto", ["auto", "required", "off"])]
        case .memory: [.toggle("memory_enabled", "Memory enabled", true), .toggle("user_profile_enabled", "User profile memory", true), .number("memory_char_limit", "Memory character limit", 2000), .number("user_char_limit", "User context limit", 2000), .toggle("write_approval", "Approve memory writes", false)]
        case .compression: [.toggle("enabled", "Compression enabled", true), .decimal("threshold", "Compression threshold", 0.5), .decimal("target_ratio", "Target ratio", 0.2), .number("protect_last_n", "Protect latest messages", 20), .number("protect_first_n", "Protect first messages", 3)]
        case .session: [.choice("mode", "Reset mode", "both", ["off", "idle", "daily", "both"]), .number("idle_minutes", "Idle minutes", 60), .number("at_hour", "Daily reset hour", 0)]
        case .approvals: [.choice("mode", "Approval mode", "off", ["off", "ask", "always"])]
        case .skills: [.toggle("write_approval", "Approve skill changes", false)]
        case .privacy: [.toggle("redact_pii", "Redact personal information", false)]
        case .voice: [.toggle("enabled", "Voice enabled", true), .text("provider", "Provider"), .text("model", "Speech model"), .text("language", "Default language")]
        case .gateway: [.toggle("enabled", "Start gateways automatically", true), .choice("management", "Management", "per_profile", ["per_profile", "all"])]
        }
    }
}

struct ConfigField: Identifiable {
    enum Kind { case toggle, text, number, decimal, choice([String]) }
    let key: String; let title: LocalizedStringKey; let kind: Kind; let fallback: Any
    var id: String { key }
    static func toggle(_ key: String, _ title: LocalizedStringKey, _ value: Bool) -> Self { .init(key: key, title: title, kind: .toggle, fallback: value) }
    static func text(_ key: String, _ title: LocalizedStringKey) -> Self { .init(key: key, title: title, kind: .text, fallback: "") }
    static func number(_ key: String, _ title: LocalizedStringKey, _ value: Int) -> Self { .init(key: key, title: title, kind: .number, fallback: value) }
    static func decimal(_ key: String, _ title: LocalizedStringKey, _ value: Double) -> Self { .init(key: key, title: title, kind: .decimal, fallback: value) }
    static func choice(_ key: String, _ title: LocalizedStringKey, _ value: String, _ options: [String]) -> Self { .init(key: key, title: title, kind: .choice(options), fallback: value) }
}

struct StudioSectionSettings: View {
    @EnvironmentObject private var store: AppStore
    let section: StudioSettingsSection
    @State private var values: JSON = [:]; @State private var loading = true; @State private var saving = false
    var body: some View {
        Form { Section { Text(section.note).font(.subheadline).foregroundStyle(.secondary) }; Section { ForEach(section.fields) { field in control(field) } }; Section { Button { Task { await save() } } label: { HStack { if saving { ProgressView() }; Text("Save settings") } }.disabled(saving) } footer: { Text("Changes are written to the selected profile: \(store.selectedProfile)") } }.navigationTitle(section.title).navigationBarTitleDisplayMode(.inline).overlay { if loading { ProgressView() } }.task(id: store.selectedProfile) { await load() }
    }
    @ViewBuilder private func control(_ field: ConfigField) -> some View {
        switch field.kind {
        case .toggle: Toggle(field.title, isOn: Binding(get: { (values[field.key] as? Bool) ?? (field.fallback as? Bool ?? false) }, set: { values[field.key] = $0 }))
        case .text: TextField(field.title, text: stringBinding(field)).textInputAutocapitalization(.never).autocorrectionDisabled()
        case .number: TextField(field.title, text: numberBinding(field, decimal: false)).keyboardType(.numberPad)
        case .decimal: TextField(field.title, text: numberBinding(field, decimal: true)).keyboardType(.decimalPad)
        case let .choice(options): Picker(field.title, selection: stringBinding(field)) { ForEach(options, id: \.self) { Text($0.capitalized.replacingOccurrences(of: "_", with: " ")).tag($0) } }
        }
    }
    private func stringBinding(_ field: ConfigField) -> Binding<String> { Binding(get: { values.string(field.key).nilIfEmpty ?? (field.fallback as? String ?? "") }, set: { values[field.key] = $0 }) }
    private func numberBinding(_ field: ConfigField, decimal: Bool) -> Binding<String> { Binding(get: { if let number = values[field.key] as? NSNumber { return number.stringValue }; return String(describing: field.fallback) }, set: { values[field.key] = decimal ? (Double($0) ?? 0) : (Int($0) ?? 0) }) }
    private func load() async { loading = true; do { let root = try await store.api.config(profile: store.selectedProfile); values = root.object(section.apiName); for field in section.fields where values[field.key] == nil { values[field.key] = field.fallback } } catch { store.errorMessage = error.localizedDescription }; loading = false }
    private func save() async { saving = true; do { try await store.api.updateConfig(profile: store.selectedProfile, section: section.apiName, values: values, restart: section == .agent || section == .proxy || section == .gateway); store.notify(String(localized: "Settings saved")) } catch { store.errorMessage = error.localizedDescription }; saving = false }
}
