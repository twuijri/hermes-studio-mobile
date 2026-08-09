import SwiftUI

private enum ChannelFieldKind: Equatable { case text, secret, toggle, commaList }
private enum ChannelFieldTarget: Equatable { case credentials, configuration }

private struct ChannelFieldSpec: Identifiable {
    let key: String
    let label: LocalizedStringKey
    let hint: LocalizedStringKey?
    var kind: ChannelFieldKind = .secret
    var target: ChannelFieldTarget = .credentials
    var placeholder = ""
    var defaultEnabled = false
    var id: String { key }
}

private struct ChannelSpec: Identifiable {
    let id: String
    let name: String
    let symbol: String
    let color: Color
    let fields: [ChannelFieldSpec]
    var exclusive = false
    var supportsCredentialClear = true
    var needsStudioPairing = false

    private static func credential(
        _ key: String,
        _ label: LocalizedStringKey,
        _ hint: LocalizedStringKey? = nil,
        kind: ChannelFieldKind = .secret,
        placeholder: String = "",
        defaultEnabled: Bool = false
    ) -> ChannelFieldSpec {
        .init(key: key, label: label, hint: hint, kind: kind, target: .credentials, placeholder: placeholder, defaultEnabled: defaultEnabled)
    }

    private static func setting(
        _ key: String,
        _ label: LocalizedStringKey,
        _ hint: LocalizedStringKey? = nil,
        kind: ChannelFieldKind = .toggle,
        placeholder: String = "",
        defaultEnabled: Bool = false
    ) -> ChannelFieldSpec {
        .init(key: key, label: label, hint: hint, kind: kind, target: .configuration, placeholder: placeholder, defaultEnabled: defaultEnabled)
    }

    /// Mirrors Hermes Studio's PlatformSettings schema, including nested extras.
    static let all: [ChannelSpec] = [
        .init(
            id: "telegram", name: "Telegram", symbol: "paperplane.fill", color: .blue,
            fields: [
                credential("token", "Bot token", "Bot token from the developer portal", placeholder: "123456:ABC-DEF…"),
                credential("proxy", "Proxy URL", "Optional platform proxy. Supports http://, https:// and socks5://", kind: .text, placeholder: "socks5://127.0.0.1:7890"),
                setting("require_mention", "Require @Mention", "Require @mention in groups to respond"),
                setting("reactions", "Reactions", "React to messages with emoji"),
                setting("free_response_chats", "Free response chats", "Chat IDs that respond without @mention (comma-separated)", kind: .text, placeholder: "chat_id1,chat_id2"),
                setting("mention_patterns", "Custom mention patterns", "Additional trigger patterns (comma-separated)", kind: .commaList, placeholder: "pattern1, pattern2"),
            ],
            exclusive: true
        ),
        .init(
            id: "discord", name: "Discord", symbol: "gamecontroller.fill", color: .indigo,
            fields: [
                credential("token", "Bot token", "Bot token from the developer portal", placeholder: "Bot token…"),
                credential("proxy", "Proxy URL", "Optional platform proxy. Supports http://, https:// and socks5://", kind: .text, placeholder: "socks5://127.0.0.1:7890"),
                setting("require_mention", "Require @Mention", "Require @mention in channels to respond"),
                setting("auto_thread", "Automatic threads", "Reply inside a thread when possible"),
                setting("reactions", "Reactions", "React to messages with emoji"),
                setting("free_response_channels", "Free response channels", "Channel IDs that respond without @mention (comma-separated)", kind: .text, placeholder: "channel_id1,channel_id2"),
                setting("allowed_channels", "Allowed channels", "Only answer in these channel IDs (comma-separated)", kind: .text, placeholder: "channel_id1,channel_id2"),
                setting("ignored_channels", "Ignored channels", "Never answer in these channel IDs (comma-separated)", kind: .text, placeholder: "channel_id1,channel_id2"),
                setting("no_thread_channels", "Channels without threads", "Reply directly in these channel IDs (comma-separated)", kind: .text, placeholder: "channel_id1,channel_id2"),
            ],
            exclusive: true
        ),
        .init(
            id: "slack", name: "Slack", symbol: "number", color: .purple,
            fields: [
                credential("token", "Bot token", "Bot token from the developer portal", placeholder: "xoxb-…"),
                setting("require_mention", "Require @Mention", "Require @mention in channels to respond"),
                setting("allow_bots", "Allow bot messages", "Permit messages sent by other bots"),
                setting("free_response_channels", "Free response channels", "Channel IDs that respond without @mention (comma-separated)", kind: .text, placeholder: "channel_id1,channel_id2"),
            ],
            exclusive: true
        ),
        .init(
            id: "whatsapp", name: "WhatsApp", symbol: "phone.bubble.fill", color: .green,
            fields: [
                credential("enabled", "WhatsApp enabled", "Pair WhatsApp in Studio before enabling it here", kind: .toggle),
                setting("require_mention", "Require @Mention", "Require @mention in groups to respond"),
                setting("free_response_chats", "Free response chats", "Chat IDs that respond without @mention (comma-separated)", kind: .text, placeholder: "chat_id1,chat_id2"),
                setting("mention_patterns", "Custom mention patterns", "Additional trigger patterns (comma-separated)", kind: .commaList, placeholder: "pattern1, pattern2"),
            ],
            exclusive: true,
            supportsCredentialClear: false,
            needsStudioPairing: true
        ),
        .init(
            id: "matrix", name: "Matrix", symbol: "square.grid.3x3.fill", color: .teal,
            fields: [
                credential("token", "Access token", "Matrix access token", placeholder: "syt_…"),
                credential("extra.user_id", "User ID", "Full Matrix user ID", kind: .text, placeholder: "@hermes:example.org"),
                credential("extra.password", "Password", "Matrix account password"),
                credential("extra.homeserver", "Homeserver", "Matrix homeserver address", kind: .text, placeholder: "https://matrix.org"),
                credential("proxy", "Proxy URL", "Optional platform proxy. Supports http://, https:// and socks5://", kind: .text, placeholder: "socks5://127.0.0.1:7890"),
                setting("require_mention", "Require @Mention", "Require @mention in rooms to respond"),
                setting("auto_thread", "Automatic threads", "Reply inside a thread when possible"),
                setting("dm_mention_threads", "DM mention threads", "Create threads for direct-message mentions"),
                setting("free_response_rooms", "Free response rooms", "Room IDs that respond without @mention (comma-separated)", kind: .text, placeholder: "room_id1,room_id2"),
            ]
        ),
        .init(
            id: "weixin", name: "Weixin", symbol: "bubble.left.and.bubble.right.fill", color: .green,
            fields: [
                credential("token", "Token", "Weixin channel token"),
                credential("extra.account_id", "Account ID", "Weixin account identifier", kind: .text),
            ],
            exclusive: true
        ),
        .init(
            id: "wecom", name: "WeCom", symbol: "building.2.fill", color: .cyan,
            fields: [
                credential("extra.bot_id", "Bot ID", "WeCom bot identifier", kind: .text),
                credential("extra.secret", "App secret", "WeCom bot secret"),
            ]
        ),
        .init(
            id: "feishu", name: "Feishu", symbol: "bird.fill", color: .blue,
            fields: [
                credential("extra.app_id", "App ID", "Application identifier", kind: .text, placeholder: "cli_…"),
                credential("extra.app_secret", "App secret", "Secret from the application console"),
                credential("extra.encrypt_key", "Encrypt key", "Event encryption key"),
                credential("extra.verification_token", "Verification token", "Event verification token"),
                setting("require_mention", "Require @Mention", "Require @mention in groups to respond"),
                setting("free_response_chats", "Free response chats", "Chat IDs that respond without @mention (comma-separated)", kind: .text, placeholder: "chat_id1,chat_id2"),
            ],
            exclusive: true
        ),
        .init(
            id: "dingtalk", name: "DingTalk", symbol: "bolt.fill", color: .blue,
            fields: [
                credential("extra.client_id", "Client ID", "Application client identifier", kind: .text),
                credential("extra.client_secret", "Client secret", "Application client secret"),
                credential("extra.app_key", "App key", "Legacy application key", kind: .text),
                credential("extra.card_template_id", "Card template ID", "Interactive card template identifier", kind: .text),
                credential("allow_all_users", "Allow all users", "Allow any user to talk to the bot", kind: .toggle),
                credential("allowed_users", "Allowed users", "Allowed user IDs (comma-separated)", kind: .text, placeholder: "user_id1,user_id2"),
                setting("require_mention", "Require @Mention", "Require @mention in groups to respond"),
                setting("free_response_chats", "Free response chats", "Chat IDs that respond without @mention (comma-separated)", kind: .text, placeholder: "chat_id1,chat_id2"),
            ],
            exclusive: true
        ),
        .init(
            id: "qqbot", name: "QQ Bot", symbol: "message.fill", color: .red,
            fields: [
                credential("extra.app_id", "QQ App ID", "QQ bot application identifier", kind: .text),
                credential("extra.client_secret", "QQ client secret", "QQ bot client secret"),
                credential("allowed_users", "Allowed users", "Allowed user IDs (comma-separated)", kind: .text, placeholder: "openid1,openid2"),
                credential("allow_all_users", "Allow all users", "Allow any user to talk to the bot", kind: .toggle),
                setting("extra.markdown_support", "Markdown support", "Render Markdown in QQ replies", defaultEnabled: true),
            ],
            exclusive: true
        ),
    ]
}

struct ChannelsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var states: [String: Channel] = [:]
    @State private var loading = true

    var body: some View {
        List {
            Section {
                ForEach(ChannelSpec.all) { spec in
                    NavigationLink {
                        ChannelEditorView(spec: spec, state: states[spec.id]) { await load() }
                    } label: {
                        HStack(spacing: 13) {
                            Image(systemName: spec.symbol)
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 43, height: 43)
                                .background(spec.color.gradient, in: RoundedRectangle(cornerRadius: 13))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(spec.name).font(.headline)
                                Text(status(spec)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Circle()
                                .fill(isConnected(spec) ? .green : .gray.opacity(0.35))
                                .frame(width: 9, height: 9)
                        }
                        .padding(.vertical, 3)
                    }
                }
            } footer: {
                Text("Channel credentials and behavior are saved in the selected Studio profile.")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Channels")
        .overlay { if loading { ProgressView() } }
        .refreshable { await load() }
        .task(id: store.selectedProfile) { await load() }
    }

    private func isConnected(_ spec: ChannelSpec) -> Bool {
        states[spec.id]?.configured == true && states[spec.id]?.enabled == true
    }

    private func status(_ spec: ChannelSpec) -> String {
        guard let state = states[spec.id] else { return String(localized: "Not configured") }
        if state.configured { return state.enabled ? String(localized: "Connected") : String(localized: "Disabled") }
        return spec.needsStudioPairing ? String(localized: "Pair in Studio") : String(localized: "Not configured")
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            let root = try await store.api.config(profile: store.selectedProfile)
            let platforms = root.object("platforms")
            let credentialStatus = root.object("platformCredentialStatus")
            var loaded: [String: Channel] = [:]
            for spec in ChannelSpec.all {
                let settings = platforms.object(spec.id)
                let values = flatten(settings)
                let explicitlyConfigured = credentialStatus[spec.id].map { raw -> Bool in
                    if let value = raw as? Bool { return value }
                    if let value = raw as? NSNumber { return value.boolValue }
                    if let value = raw as? String { return ["true", "1", "yes"].contains(value.lowercased()) }
                    return false
                }
                loaded[spec.id] = Channel(
                    id: spec.id,
                    enabled: settings.bool("enabled", default: true),
                    configured: explicitlyConfigured ?? inferConfigured(spec, values: values),
                    values: values
                )
            }
            states = loaded
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func flatten(_ root: JSON) -> [String: String] {
        var result: [String: String] = [:]
        func visit(_ raw: Any, path: String) {
            if let object = raw as? JSON {
                for (key, value) in object { visit(value, path: path.isEmpty ? key : "\(path).\(key)") }
            } else if let array = raw as? [Any] {
                result[path] = array.map { String(describing: $0) }.joined(separator: ", ")
            } else if !(raw is NSNull) {
                result[path] = String(describing: raw)
            }
        }
        visit(root, path: "")
        return result
    }

    private func inferConfigured(_ spec: ChannelSpec, values: [String: String]) -> Bool {
        switch spec.id {
        case "matrix":
            return !(values["extra.homeserver"] ?? "").isEmpty && (
                !(values["token"] ?? "").isEmpty ||
                    (!(values["extra.user_id"] ?? "").isEmpty && !(values["extra.password"] ?? "").isEmpty)
            )
        case "whatsapp": return Bool(values["enabled"] ?? "") ?? false
        default:
            return spec.fields
                .filter { $0.target == .credentials && $0.kind != .toggle }
                .contains { !(values[$0.key] ?? "").isEmpty }
        }
    }
}

private struct ChannelEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.openURL) private var openURL
    let spec: ChannelSpec
    let state: Channel?
    let onChange: () async -> Void

    @State private var values: [String: String] = [:]
    @State private var enabled = true
    @State private var saving = false
    @State private var initialized = false
    @State private var revealed: Set<String> = []
    @State private var qrStatus = "idle"

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: spec.symbol)
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(spec.color.gradient, in: RoundedRectangle(cornerRadius: 15))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(spec.name).font(.title3.bold())
                        Text(status).foregroundStyle(.secondary)
                    }
                }
            }

            if spec.exclusive {
                Section {
                    Label {
                        Text("This platform uses exclusive token locking. Each profile must use a different identity token to avoid conflicts with other profiles.")
                    } icon: {
                        Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
                    }
                }
            }

            if !ownsEnabledCredential {
                Section {
                    Toggle("Enabled", isOn: $enabled)
                    Text("Hermes answers on this channel when the gateway is running.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if spec.id == "weixin" {
                Section {
                    Button {
                        Task { await startWeixinQr() }
                    } label: {
                        HStack {
                            if ["loading", "waiting", "scanned"].contains(qrStatus) { ProgressView() }
                            Label("Link Weixin with QR", systemImage: "qrcode.viewfinder")
                            Spacer()
                        }
                    }
                    Text(qrStatusText).font(.caption).foregroundStyle(.secondary)
                }
            }

            fieldSection(.credentials, title: "Credentials")
            fieldSection(.configuration, title: "Behavior and access")

            if spec.needsStudioPairing {
                Section {
                    Label("Pair WhatsApp by scanning the QR code in Studio, then edit its behavior here.", systemImage: "qrcode.viewfinder")
                }
            }

            Section {
                Button {
                    Task { await save() }
                } label: {
                    HStack {
                        if saving { ProgressView() }
                        Text("Save and restart the gateway")
                    }
                }
                .disabled(saving)
            }

            if state?.configured == true && spec.supportsCredentialClear {
                Section {
                    Button("Clear credentials", role: .destructive) { Task { await clear() } }
                }
            }

            Section {
                Text("Saving writes these values to your server and restarts the gateway so the channel picks them up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(spec.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { initializeIfNeeded() }
    }

    @ViewBuilder
    private func fieldSection(_ target: ChannelFieldTarget, title: LocalizedStringKey) -> some View {
        let fields = spec.fields.filter { $0.target == target }
        if !fields.isEmpty {
            Section(title) {
                ForEach(fields) { field in
                    switch field.kind {
                    case .toggle:
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle(field.label, isOn: toggleBinding(field))
                            if let hint = field.hint { Text(hint).font(.caption).foregroundStyle(.secondary) }
                        }
                    case .secret:
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                if revealed.contains(field.key) {
                                    TextField(field.label, text: binding(field.key), prompt: prompt(field))
                                } else {
                                    SecureField(field.label, text: binding(field.key), prompt: prompt(field))
                                }
                                Button {
                                    if revealed.contains(field.key) { revealed.remove(field.key) }
                                    else { revealed.insert(field.key) }
                                } label: {
                                    Image(systemName: revealed.contains(field.key) ? "eye.slash" : "eye")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(revealed.contains(field.key) ? "Hide value" : "Show value")
                            }
                            if let hint = field.hint { Text(hint).font(.caption).foregroundStyle(.secondary) }
                        }
                    case .text, .commaList:
                        VStack(alignment: .leading, spacing: 5) {
                            TextField(field.label, text: binding(field.key), prompt: prompt(field))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                            if let hint = field.hint { Text(hint).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
        }
    }

    private var ownsEnabledCredential: Bool {
        spec.fields.contains { $0.target == .credentials && $0.key == "enabled" }
    }

    private var status: LocalizedStringKey {
        if state?.configured == true { return state?.enabled == true ? "Connected" : "Disabled" }
        return "Not configured"
    }

    private func prompt(_ field: ChannelFieldSpec) -> Text? {
        field.placeholder.isEmpty ? nil : Text(field.placeholder)
    }

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { values[key] ?? "" }, set: { values[key] = $0 })
    }

    private func toggleBinding(_ field: ChannelFieldSpec) -> Binding<Bool> {
        Binding(
            get: { Bool(values[field.key] ?? "") ?? field.defaultEnabled },
            set: { values[field.key] = String($0) }
        )
    }

    private func initializeIfNeeded() {
        guard !initialized else { return }
        values = state?.values ?? [:]
        for field in spec.fields where field.kind == .toggle && values[field.key] == nil {
            values[field.key] = String(field.defaultEnabled)
        }
        enabled = state?.enabled ?? true
        initialized = true
    }

    private func typedValue(_ field: ChannelFieldSpec) -> Any {
        let raw = values[field.key] ?? ""
        switch field.kind {
        case .toggle: return Bool(raw) ?? field.defaultEnabled
        case .commaList:
            return raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        case .text, .secret: return raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func put(_ value: Any, at path: String, in root: inout JSON) {
        var pieces = path.split(separator: ".").map(String.init)
        guard let first = pieces.first else { return }
        pieces.removeFirst()
        if pieces.isEmpty { root[first] = value; return }
        var child = root[first] as? JSON ?? [:]
        put(value, at: pieces.joined(separator: "."), in: &child)
        root[first] = child
    }

    private func save() async {
        saving = true
        defer { saving = false }
        do {
            var credentials: JSON = [:]
            var configuration: JSON = [:]
            for field in spec.fields {
                if field.target == .credentials { put(typedValue(field), at: field.key, in: &credentials) }
                else { put(typedValue(field), at: field.key, in: &configuration) }
            }
            if !ownsEnabledCredential { configuration["enabled"] = enabled }

            if !configuration.isEmpty {
                try await store.api.updateConfig(
                    profile: store.selectedProfile,
                    section: spec.id,
                    values: configuration,
                    restart: credentials.isEmpty
                )
            }
            if !credentials.isEmpty {
                try await store.api.updateCredentials(profile: store.selectedProfile, platform: spec.id, values: credentials)
            }
            store.notify(String(localized: "Channel saved"))
            await onChange()
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private func clear() async {
        do {
            try await store.api.clearCredentials(profile: store.selectedProfile, platform: spec.id)
            values = values.mapValues { _ in "" }
            await onChange()
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private var qrStatusText: LocalizedStringKey {
        switch qrStatus {
        case "loading": "Fetching a new QR code…"
        case "waiting": "Scan the code that opened, then return here."
        case "scanned": "Code scanned — confirm the link in Weixin."
        case "confirmed": "Weixin is linked."
        case "expired": "The QR code expired. Tap to try again."
        case "error": "Could not complete QR linking. Tap to retry."
        default: "Open a QR code and complete pairing without leaving the app."
        }
    }

    private func startWeixinQr() async {
        qrStatus = "loading"
        do {
            let code = try await store.api.weixinQrCode(profile: store.selectedProfile)
            qrStatus = "waiting"
            openURL(code.url)
            for _ in 0..<100 {
                try await Task.sleep(for: .seconds(3))
                guard qrStatus != "expired" else { return }
                guard let poll = try? await store.api.weixinQrStatus(profile: store.selectedProfile, code: code.id) else { continue }
                switch poll.string("status") {
                case "confirmed":
                    try await store.api.saveWeixinCredentials(profile: store.selectedProfile, status: poll)
                    values["token"] = poll.string("token")
                    values["extra.account_id"] = poll.string("account_id")
                    qrStatus = "confirmed"
                    store.notify(String(localized: "Weixin linked"))
                    await onChange()
                    return
                case "expired": qrStatus = "expired"; return
                case "scaned", "scaned_but_redirect": qrStatus = "scanned"
                default: break
                }
            }
            qrStatus = "expired"
        } catch {
            qrStatus = "error"
            store.errorMessage = error.localizedDescription
        }
    }
}
