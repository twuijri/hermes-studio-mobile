import SwiftUI

struct ChannelFieldSpec { let key: String; let label: LocalizedStringKey; var secret = true; var hint = "" }
struct ChannelSpec: Identifiable {
    let id: String; let name: String; let symbol: String; let color: Color; let fields: [ChannelFieldSpec]; var external = false
    static let all: [ChannelSpec] = [
        .init(id: "telegram", name: "Telegram", symbol: "paperplane.fill", color: .blue, fields: [.init(key: "token", label: "Bot token", hint: "From @BotFather"), .init(key: "proxy", label: "Proxy", secret: false, hint: "Optional")]),
        .init(id: "discord", name: "Discord", symbol: "gamecontroller.fill", color: .indigo, fields: [.init(key: "token", label: "Bot token", hint: "Developer portal"), .init(key: "proxy", label: "Proxy", secret: false, hint: "Optional")]),
        .init(id: "slack", name: "Slack", symbol: "number", color: .purple, fields: [.init(key: "token", label: "Bot token", hint: "xoxb-…")]),
        .init(id: "whatsapp", name: "WhatsApp", symbol: "phone.bubble.fill", color: .green, fields: [], external: true),
        .init(id: "matrix", name: "Matrix", symbol: "square.grid.3x3.fill", color: .teal, fields: [.init(key: "extra.homeserver", label: "Homeserver", secret: false, hint: "https://matrix.org"), .init(key: "token", label: "Access token"), .init(key: "extra.user_id", label: "User ID", secret: false, hint: "@name:server"), .init(key: "extra.password", label: "Password"), .init(key: "proxy", label: "Proxy", secret: false, hint: "Optional")]),
        .init(id: "weixin", name: "Weixin", symbol: "bubble.left.and.bubble.right.fill", color: .green, fields: [.init(key: "token", label: "Token"), .init(key: "extra.account_id", label: "Account ID", secret: false)]),
        .init(id: "wecom", name: "WeCom", symbol: "building.2.fill", color: .cyan, fields: [.init(key: "extra.bot_id", label: "Bot ID", secret: false), .init(key: "extra.secret", label: "Secret")]),
        .init(id: "feishu", name: "Feishu", symbol: "bird.fill", color: .blue, fields: [.init(key: "extra.app_id", label: "App ID", secret: false), .init(key: "extra.app_secret", label: "App secret"), .init(key: "extra.encrypt_key", label: "Encrypt key"), .init(key: "extra.verification_token", label: "Verification token")]),
        .init(id: "dingtalk", name: "DingTalk", symbol: "bolt.fill", color: .blue, fields: [.init(key: "extra.client_id", label: "Client ID", secret: false), .init(key: "extra.client_secret", label: "Client secret"), .init(key: "extra.app_key", label: "App key")]),
        .init(id: "qqbot", name: "QQ Bot", symbol: "message.fill", color: .red, fields: [.init(key: "extra.app_id", label: "App ID", secret: false), .init(key: "extra.client_secret", label: "Client secret")]),
    ]
}

struct ChannelsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var states: [String: Channel] = [:]
    @State private var loading = true
    var body: some View {
        List {
            Section { ForEach(ChannelSpec.all) { spec in NavigationLink { ChannelEditorView(spec: spec, state: states[spec.id]) { await load() } } label: { HStack(spacing: 13) { Image(systemName: spec.symbol).font(.title3).foregroundStyle(.white).frame(width: 43, height: 43).background(spec.color.gradient, in: RoundedRectangle(cornerRadius: 13)); VStack(alignment: .leading, spacing: 4) { Text(spec.name).font(.headline); Text(status(spec)).font(.caption).foregroundStyle(.secondary) }; Spacer(); Circle().fill(states[spec.id]?.configured == true ? .green : .gray.opacity(0.35)).frame(width: 9, height: 9) }.padding(.vertical, 3) } } } footer: { Text("Channel credentials are saved in your selected Studio profile. Each icon represents its actual platform.") }
        }.listStyle(.insetGrouped).navigationTitle("Channels").overlay { if loading { ProgressView() } }.refreshable { await load() }.task(id: store.selectedProfile) { await load() }
    }
    private func status(_ spec: ChannelSpec) -> String { if spec.external { return String(localized: "Pair in Studio") }; guard let state = states[spec.id] else { return String(localized: "Not configured") }; return state.configured ? (state.enabled ? String(localized: "Connected") : String(localized: "Disabled")) : String(localized: "Not configured") }
    private func load() async {
        loading = true; defer { loading = false }
        do { let root = try await store.api.config(profile: store.selectedProfile); let platforms = root.object("platforms"), credentials = root.object("platformCredentialStatus"); for spec in ChannelSpec.all { let settings = platforms.object(spec.id); states[spec.id] = Channel(id: spec.id, enabled: settings.bool("enabled", default: true), configured: credentials.bool(spec.id), values: [:]) } } catch { store.errorMessage = error.localizedDescription }
    }
}

private struct ChannelEditorView: View {
    @EnvironmentObject private var store: AppStore
    let spec: ChannelSpec; let state: Channel?; let onChange: () async -> Void
    @State private var values: [String: String] = [:]
    @State private var enabled = true; @State private var saving = false
    var body: some View {
        Form {
            Section { HStack(spacing: 14) { Image(systemName: spec.symbol).font(.title2).foregroundStyle(.white).frame(width: 52, height: 52).background(spec.color.gradient, in: RoundedRectangle(cornerRadius: 15)); VStack(alignment: .leading) { Text(spec.name).font(.title3.bold()); Text(state?.configured == true ? "Configured" : "Not configured").foregroundStyle(.secondary) } } }
            if spec.external { Section { Label("Pair this channel from the Hermes Studio web interface, then refresh here.", systemImage: "qrcode.viewfinder") } }
            else {
                Section("Credentials") { ForEach(spec.fields, id: \.key) { field in if field.secret { SecureField(field.label, text: binding(field.key), prompt: Text(field.hint)) } else { TextField(field.label, text: binding(field.key), prompt: Text(field.hint)).textInputAutocapitalization(.never).autocorrectionDisabled() } } }
                Section { Toggle("Enabled", isOn: $enabled); Button { Task { await save() } } label: { HStack { if saving { ProgressView() }; Text("Save and restart channel") } }.disabled(saving || values.values.allSatisfy(\.isEmpty)) }
                if state?.configured == true { Section { Button("Clear credentials", role: .destructive) { Task { await clear() } } } }
            }
        }.navigationTitle(spec.name).navigationBarTitleDisplayMode(.inline).onAppear { enabled = state?.enabled ?? true }
    }
    private func binding(_ key: String) -> Binding<String> { Binding(get: { values[key] ?? "" }, set: { values[key] = $0 }) }
    private func save() async { saving = true; do { try await store.api.updateCredentials(profile: store.selectedProfile, platform: spec.id, values: values.filter { !$0.value.isEmpty }); try await store.api.updateConfig(profile: store.selectedProfile, section: spec.id, values: ["enabled": enabled], restart: true); store.notify(String(localized: "Channel saved")); await onChange() } catch { store.errorMessage = error.localizedDescription }; saving = false }
    private func clear() async { do { try await store.api.clearCredentials(profile: store.selectedProfile, platform: spec.id); await onChange() } catch { store.errorMessage = error.localizedDescription } }
}
