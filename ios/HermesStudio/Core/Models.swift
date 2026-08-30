import Foundation

typealias JSON = [String: Any]

enum StudioTimestamp {
    static func date(from raw: String?) -> Date? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if let value = Double(raw), value > 0 {
            // Conversation messages use Unix seconds; group messages and a few
            // older endpoints use milliseconds.
            let seconds = value >= 100_000_000_000 ? value / 1_000 : value
            return Date(timeIntervalSince1970: seconds)
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }
}

extension Dictionary where Key == String, Value == Any {
    func string(_ keys: String...) -> String {
        for key in keys {
            if let value = self[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return value }
            if let value = self[key] as? NSNumber { return value.stringValue }
        }
        return ""
    }

    func bool(_ key: String, default fallback: Bool = false) -> Bool {
        if let value = self[key] as? Bool { return value }
        if let value = self[key] as? NSNumber { return value.boolValue }
        if let value = self[key] as? String { return ["true", "1", "yes"].contains(value.lowercased()) }
        return fallback
    }

    func int(_ key: String, default fallback: Int = 0) -> Int {
        if let value = self[key] as? Int { return value }
        if let value = self[key] as? NSNumber { return value.intValue }
        if let value = self[key] as? String, let number = Int(value) { return number }
        return fallback
    }

    func double(_ key: String, default fallback: Double = 0) -> Double {
        if let value = self[key] as? Double { return value }
        if let value = self[key] as? NSNumber { return value.doubleValue }
        if let value = self[key] as? String, let number = Double(value) { return number }
        return fallback
    }

    func object(_ key: String) -> JSON { self[key] as? JSON ?? [:] }
    func array(_ key: String) -> [Any] { self[key] as? [Any] ?? [] }
    func objects(_ key: String) -> [JSON] { array(key).compactMap { $0 as? JSON } }
    func strings(_ key: String) -> [String] { array(key).compactMap { $0 as? String } }
}

extension Array where Element == Any {
    var objects: [JSON] { compactMap { $0 as? JSON } }
}

struct Profile: Identifiable, Hashable {
    let name: String
    var model: String?
    var active: Bool
    var gatewayStatus: String
    var avatar: AvatarSpec?
    var id: String { name }

    init(_ json: JSON) {
        name = json.string("name")
        let rawModel = json.string("model")
        model = rawModel.isEmpty || rawModel == "—" ? nil : rawModel
        active = json.bool("active")
        gatewayStatus = json.string("gatewayStatus", "gateway_status", "alias")
        avatar = AvatarSpec(json["avatar"])
    }
}

struct AvatarSpec: Hashable {
    let type: String
    let seed: String?
    let dataURL: String?
    let updatedAt: Int64

    init?(_ raw: Any?) {
        let json: JSON?
        if let object = raw as? JSON { json = object }
        else if let text = raw as? String,
                let data = text.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data) as? JSON { json = object }
        else { json = nil }
        guard let json else { return nil }
        type = json.string("type").isEmpty ? "default" : json.string("type")
        seed = json.string("seed").nilIfEmpty
        dataURL = json.string("dataUrl", "data_url").nilIfEmpty
        if let value = json["updatedAt"] as? NSNumber {
            updatedAt = value.int64Value
        } else if let value = json["updated_at"] as? NSNumber {
            updatedAt = value.int64Value
        } else {
            updatedAt = Int64(json.string("updatedAt", "updated_at")) ?? 0
        }
    }
}

struct SessionSummary: Identifiable, Hashable {
    let id: String
    var title: String
    var model: String
    var provider: String
    var updatedAt: String
    var profile: String
    var agentID: String
    var source: String
    var categoryID: Int?
    var archived: Bool
    var preview: String
    var messageCount: Int

    init(_ json: JSON, profile fallbackProfile: String = "") {
        id = json.string("id", "session_id", "sessionId")
        title = json.string("title", "name").nilIfEmpty ?? String(localized: "New conversation")
        model = json.string("model")
        provider = json.string("provider")
        updatedAt = json.string("last_active", "ended_at", "started_at", "updatedAt", "updated_at", "created_at", "timestamp")
        profile = json.string("profile").nilIfEmpty ?? fallbackProfile
        agentID = json.string("agent", "agentId", "agent_id", "codingAgentId", "coding_agent_id").nilIfEmpty ?? "hermes"
        source = json.string("source", "sessionSource", "session_source")
        let rawCategory = json["category_id"] ?? json["categoryId"]
        categoryID = (rawCategory as? NSNumber)?.intValue ?? Int(String(describing: rawCategory ?? ""))
        archived = json.bool("is_archived", "archived")
        preview = json.string("preview", "last_message", "lastMessage")
        messageCount = json.int("message_count", "messageCount")
    }

    var agentDisplayName: String { AgentIdentity.displayName(for: agentID) }
}

struct SessionCategory: Identifiable, Hashable {
    let id: Int
    var name: String
    init(_ json: JSON) { id = json.int("id"); name = json.string("name") }
}

struct WorkflowItem: Identifiable, Hashable {
    let id: String
    var name: String
    var profile: String
    var workspace: String
    var nodeCount: Int
    var updatedAt: Int64
    init(_ json: JSON) {
        id = json.string("id")
        name = json.string("name").nilIfEmpty ?? String(localized: "Untitled workflow")
        profile = json.string("profile")
        workspace = json.string("workspace")
        nodeCount = json.array("nodes").count
        updatedAt = (json["updated_at"] as? NSNumber)?.int64Value ?? 0
    }
}

struct WorkflowRun: Identifiable, Hashable {
    let id: String
    var workflowID: String
    var status: String
    var error: String
    var createdAt: Int64
    var nodes: [WorkflowRunNode]
    init(_ json: JSON) {
        id = json.string("id")
        workflowID = json.string("workflow_id", "workflowId")
        status = json.string("status")
        error = json.string("error")
        createdAt = (json["created_at"] as? NSNumber)?.int64Value ?? 0
        nodes = json.objects("node_sessions").map(WorkflowRunNode.init)
    }
}

struct WorkflowRunNode: Identifiable, Hashable {
    let id: String
    var nodeID: String
    var agent: String
    var status: String
    var error: String
    var executionID: String
    init(_ json: JSON) {
        id = json.string("id").nilIfEmpty ?? json.string("node_id")
        nodeID = json.string("node_id", "nodeId")
        agent = json.string("agent")
        status = json.string("status")
        error = json.string("error")
        executionID = json.string("execution_id", "executionId")
    }
}

enum AgentIdentity {
    static func canonicalID(_ raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "ekko", "ekko-agent": return "ekko-agent"
        case "claude", "claude-code": return "claude-code"
        case "codex": return "codex"
        case "pi": return "pi"
        default: return "hermes"
        }
    }

    static func displayName(for raw: String) -> String {
        switch canonicalID(raw) {
        case "ekko-agent": return "Ekko"
        case "claude-code": return "Claude Code"
        case "codex": return "Codex"
        case "pi": return "Pi"
        default: return "Hermes"
        }
    }
}

struct AgentRuntimeStatus: Identifiable, Hashable {
    let id: String
    var installed: Bool
    var source: String
    var path: String
    var version: String
    var error: String

    init(_ json: JSON) {
        id = AgentIdentity.canonicalID(json.string("id", "agent", "name"))
        installed = json.bool("installed")
        source = json.string("source").nilIfEmpty ?? (installed ? "user-cli" : "not-installed")
        path = json.string("path")
        version = json.string("version", "rawVersion")
        error = json.string("error")
    }
}

struct CodingAgentTool: Identifiable, Hashable {
    let id: String
    var name: String
    var provider: String
    var command: String
    var packageName: String
    var installed: Bool
    var version: String
    var source: String
    var path: String
    var error: String

    init(_ json: JSON) {
        id = AgentIdentity.canonicalID(json.string("id"))
        name = json.string("name").nilIfEmpty ?? AgentIdentity.displayName(for: id)
        provider = json.string("provider")
        command = json.string("command")
        packageName = json.string("packageName", "package_name")
        installed = json.bool("installed")
        version = json.string("version", "rawVersion")
        source = json.string("source").nilIfEmpty ?? (installed ? "user-cli" : "not-installed")
        path = json.string("path")
        error = json.string("error")
    }
}

struct ProfileRuntime: Identifiable, Hashable {
    let id: String
    var bridgeRunning: Bool
    var gatewayRunning: Bool
    var gatewayURL: String
    var error: String
    init(_ json: JSON) { id = json.string("profile"); let bridge = json.object("bridge"), gateway = json.object("gateway"); bridgeRunning = bridge.bool("running"); gatewayRunning = gateway.bool("running"); gatewayURL = gateway.string("url"); error = bridge.string("error").nilIfEmpty ?? gateway.string("error") }
}

struct EkkoMemoryItem: Identifiable, Hashable {
    let id: String; var title: String; var content: String; var status: String; var revision: Int; var tags: [String]
    init(_ json: JSON) { id = json.string("id"); title = json.string("title"); content = json.string("content"); status = json.string("status"); revision = json.int("revision"); tags = json.strings("tags") }
}

struct EkkoSkillItem: Identifiable, Hashable {
    let id: String; var name: String; var description: String; var category: String; var source: String; var enabled: Bool; var content: String
    init(_ json: JSON) { name = json.string("name"); id = name; description = json.string("description"); category = json.string("category"); source = json.string("source"); enabled = json.bool("enabled"); content = json.string("content") }
}

struct EkkoMCPItem: Identifiable, Hashable {
    let id: String; var name: String; var managed: Bool; var enabled: Bool; var command: String; var arguments: [String]; var url: String
    init(_ json: JSON) { name = json.string("name"); id = name; managed = json.bool("managed"); let config = json.object("config"); enabled = config.bool("enabled", default: true); command = config.string("command"); arguments = config.strings("args"); url = config.string("url") }
}

struct ProviderSummary: Identifiable, Hashable {
    let id: String; var label: String; var baseURL: String; var models: [String]; var credentialConfigured: Bool; var refreshable: Bool
    init(_ json: JSON) { id = json.string("provider", "id", "provider_key"); label = json.string("label").nilIfEmpty ?? id; baseURL = json.string("base_url"); models = json.strings("models"); credentialConfigured = !json.string("api_key").isEmpty || json.bool("credential_configured"); refreshable = json.bool("model_refreshable") }
}

struct StudioFileItem: Identifiable, Hashable { let id: String; var name: String; var path: String; var isDirectory: Bool; var size: Int; var modified: String; init(_ j: JSON) { path = j.string("path"); id = path; name = j.string("name"); isDirectory = j["isDir"] == nil ? j.bool("is_dir") : j.bool("isDir"); size = j.int("size"); modified = j.string("modTime", "modified") } }
struct StudioLogFile: Identifiable, Hashable { let id: String; var name: String; var size: String; var modified: String; init(_ j: JSON) { name = j.string("name"); id = name; size = j.string("size"); modified = j.string("modified") } }
struct StudioLogEntry: Identifiable, Hashable { let id = UUID(); var timestamp: String; var level: String; var logger: String; var message: String; var raw: String; init(_ j: JSON) { timestamp = j.string("timestamp"); level = j.string("level"); logger = j.string("logger"); message = j.string("message"); raw = j.string("raw") } }
struct AppRelayInfo: Hashable { var connected: Bool; var machineID: String; var pairingCode: String; var route: String; var relayURL: String; init(_ j: JSON) { connected = j.bool("connected"); machineID = j.string("machineId"); pairingCode = j.string("pairingCode"); route = j.string("route"); relayURL = j.string("relayUrl") } }
struct AppConnectionItem: Identifiable, Hashable { let id: Int; var name: String; var model: String; var type: String; var active: Bool; var online: Bool; init(_ j: JSON) { id = j.int("id"); name = j.string("device_name"); model = [j.string("device_brand"), j.string("device_model")].filter { !$0.isEmpty }.joined(separator: " "); type = j.string("connection_type"); active = j.bool("active"); online = j.bool("online") } }
struct StudioDevice: Identifiable, Hashable { let id: String; var name: String; var url: String; var online: Bool; var inbound: String; var outbound: String; var version: String; init(_ j: JSON) { id = j.string("id", "device_id"); name = j.string("computer_name").nilIfEmpty ?? id; url = j.string("url"); online = j.bool("online"); inbound = j.string("inbound_status"); outbound = j.string("outbound_status"); version = j.string("hermes_web_ui_version") } }
struct PeerConnection: Identifiable, Hashable { let id: String; var name: String; var url: String; var role: String; init(_ j: JSON) { id = j.string("id"); name = j.string("computer_name"); url = j.string("url"); role = j.string("role") } }

struct Message: Identifiable, Hashable {
    let id: String
    let role: String
    let content: String
    let timestamp: String?

    init(_ json: JSON) {
        id = json.string("id", "message_id").nilIfEmpty ?? UUID().uuidString
        role = json.string("role", "sender")
        if let text = json["content"] as? String { content = text }
        else if let blocks = json["content"] as? [Any] {
            content = blocks.compactMap { block -> String? in
                guard let item = block as? JSON else { return nil }
                return item.string("text", "content").nilIfEmpty
            }.joined(separator: "\n")
        } else { content = json.string("text", "message") }
        timestamp = json.string("timestamp", "createdAt", "created_at").nilIfEmpty
    }

    var sentAt: Date? { StudioTimestamp.date(from: timestamp) }
}

struct Room: Identifiable, Hashable {
    let id: String
    var name: String
    var agentCount: Int
    var memberCount: Int
    var updatedAt: String?

    init(_ json: JSON) {
        id = json.string("id", "roomId", "room_id")
        name = json.string("name", "title").nilIfEmpty ?? String(localized: "Group")
        agentCount = json.int("agentCount", default: json.int("agent_count"))
        memberCount = json.int("memberCount", default: json.int("member_count"))
        updatedAt = json.string("updatedAt", "updated_at").nilIfEmpty
    }
}

struct RoomMessage: Identifiable, Hashable {
    let id: String
    let sender: String
    let content: String
    let isAgent: Bool
    let timestamp: String?

    init(_ json: JSON) {
        id = json.string("id").nilIfEmpty ?? UUID().uuidString
        sender = json.string("senderName", "sender_name", "senderId", "sender_id", "name")
        content = json.string("content", "text", "message")
        isAgent = json.string("role") == "assistant" || json.bool("isAgent") || json.bool("is_agent")
        timestamp = json.string("timestamp", "createdAt", "created_at").nilIfEmpty
    }
}

enum ToolStatus: String, Hashable { case running, done, error }

struct ToolStep: Identifiable, Hashable {
    let id: String
    var name: String
    var detail: String?
    var status: ToolStatus
    var duration: Double?
    var startedAt: Date
}

struct ChatLine: Identifiable, Hashable {
    let id: UUID
    var text: String
    var fromUser: Bool
    var isError: Bool
    var timestamp: Date?
    var sender: String?
    var reasoning: String
    var isStreaming: Bool
    var tools: [ToolStep]
    var startedAt: Date?
    var finishedAt: Date?

    init(text: String, fromUser: Bool, isError: Bool = false, timestamp: Date? = Date(), sender: String? = nil, reasoning: String = "", isStreaming: Bool = false, tools: [ToolStep] = []) {
        id = UUID(); self.text = text; self.fromUser = fromUser; self.isError = isError; self.timestamp = timestamp
        self.sender = sender; self.reasoning = reasoning; self.isStreaming = isStreaming; self.tools = tools
        startedAt = isStreaming ? (timestamp ?? .now) : nil; finishedAt = isStreaming ? nil : timestamp
    }
}

struct PendingSkillWrite: Identifiable, Hashable {
    let id: String
    let action: String
    let summary: String
    let origin: String
    let createdAt: Int?

    init(_ json: JSON) {
        id = json.string("id")
        action = json.string("action")
        summary = json.string("summary")
        origin = json.string("origin")
        createdAt = json["created_at"] as? Int
    }
}

struct ModelOption: Identifiable, Hashable {
    let id: String
    let name: String
    let provider: String

    init(_ json: JSON) {
        id = json.string("id", "model", "name")
        name = json.string("name", "label").nilIfEmpty ?? id
        provider = json.string("provider")
    }
}

struct KanbanBoard: Identifiable, Hashable {
    let id: String
    let name: String
    init(_ json: JSON) { id = json.string("id", "slug", "name"); name = json.string("name", "title", "displayName", "display_name").nilIfEmpty ?? id }
}

enum KanbanStatus: String, CaseIterable, Identifiable {
    case triage, todo, scheduled, ready, running, blocked, review, done
    var id: String { rawValue }
    var title: String {
        switch self {
        case .triage: return String(localized: "Triage")
        case .todo: return String(localized: "To do")
        case .scheduled: return String(localized: "Scheduled")
        case .ready: return String(localized: "Ready")
        case .running: return String(localized: "Running")
        case .blocked: return String(localized: "Blocked")
        case .review: return String(localized: "Review")
        case .done: return String(localized: "Done")
        }
    }
    var colorName: String { rawValue }
}

struct KanbanTask: Identifiable, Hashable {
    let id: String
    var title: String
    var description: String
    var status: String
    var priority: String
    var assignee: String?
    var tags: [String]
    var updatedAt: String?

    init(_ json: JSON) {
        id = json.string("id")
        title = json.string("title", "name").nilIfEmpty ?? String(localized: "Untitled task")
        description = json.string("description", "body")
        status = json.string("status", "column").nilIfEmpty ?? "todo"
        priority = json.string("priority").nilIfEmpty ?? "medium"
        assignee = json.string("assignee", "assigned_to", "profile").nilIfEmpty
        tags = json.strings("tags").isEmpty ? json.strings("skills") : json.strings("tags")
        updatedAt = json.string("updatedAt", "updated_at").nilIfEmpty
    }
}

struct JourneyNode: Identifiable, Hashable { let id: String; let label: String; let kind: String; let category: String; let useCount: Int; let pinned: Bool; init(_ json: JSON) { id = json.string("id"); label = json.string("label", "title").nilIfEmpty ?? id; kind = json.string("kind"); category = json.string("category"); useCount = json.int("useCount", "use_count"); pinned = json.bool("pinned") } }
struct JourneyEdge: Hashable { let source: String; let target: String; init(_ json: JSON) { source = json.string("source"); target = json.string("target") } }
struct JourneyGraph { let profile: String; let nodes: [JourneyNode]; let edges: [JourneyEdge]; let clusters: [JSON]; let memories: [JSON]; let stats: JSON; init(_ root: JSON) { profile = root.string("profile"); let graph = root.object("graph"); nodes = graph.objects("nodes").map(JourneyNode.init); edges = graph.objects("edges").map(JourneyEdge.init); clusters = graph.objects("clusters"); memories = graph.objects("memory"); stats = graph.object("stats") } }
struct SkillUsageRow: Identifiable { let id: String; let views: Int; let edits: Int; let total: Int; let percentage: Double; let lastUsed: Double?; init(_ json: JSON) { id = json.string("skill"); views = json.int("view_count"); edits = json.int("manage_count"); total = json.int("total_count"); percentage = json.double("percentage"); lastUsed = (json["last_used_at"] as? NSNumber)?.doubleValue } }
struct SkillUsageStats { let days: Int; let totalLoads: Int; let totalEdits: Int; let totalActions: Int; let distinct: Int; let top: [SkillUsageRow]; let daily: [JSON]; init(_ root: JSON) { days = root.int("period_days"); let summary = root.object("summary"); totalLoads = summary.int("total_skill_loads"); totalEdits = summary.int("total_skill_edits"); totalActions = summary.int("total_skill_actions"); distinct = summary.int("distinct_skills_used"); top = root.objects("top_skills").map(SkillUsageRow.init); daily = root.objects("by_day") } }
struct WebhookEndpoint: Identifiable { let id: String; var name: String; var url: String; var events: [String]; var profiles: [String]; var enabled: Bool; var includeContent: Bool; var includeUserContent: Bool; var privateNetwork: Bool; var retries: Int; var runtime: JSON; init(_ json: JSON) { id = json.string("id"); name = json.string("name"); url = json.string("url"); events = json.strings("event_types"); profiles = json.strings("profiles"); enabled = json.bool("enabled"); includeContent = json.bool("include_content"); includeUserContent = json.bool("include_user_content"); privateNetwork = json.bool("allow_private_network"); retries = json.int("max_retries"); runtime = json.object("runtime") } }
struct RuntimeVersionStatus { let platform: String; let activeRuntime: String; let activeWebUI: String; let installedRuntime: [JSON]; let installedWebUI: [JSON]; let remoteRuntime: [String]; let remoteWebUI: [String]; let runtimeError: String; init(_ root: JSON) { platform = root.string("platform"); let hermes = root.object("hermes"), web = root.object("webui"); activeRuntime = hermes.string("activeVersion"); activeWebUI = web.string("activeVersion"); installedRuntime = hermes.objects("installed"); installedWebUI = web.objects("installed"); remoteRuntime = hermes.strings("remoteVersions"); remoteWebUI = web.strings("remoteVersions"); runtimeError = hermes.string("migrationError", "activationError") } }
struct ThemeSettings { var fontSize: Double; var textColor: String; var accentColor: String; let background: JSON; init(_ root: JSON) { fontSize = root.double("fontSize"); textColor = root.string("textColor"); accentColor = root.string("accentColor"); background = root.object("background") } }

struct CronJob: Identifiable, Hashable {
    let id: String
    var name: String
    var schedule: String
    var enabled: Bool
    var prompt: String
    var profile: String
    var timezone: String
    var lastRun: String?
    var nextRun: String?

    init(_ json: JSON) {
        id = json.string("id", "jobId", "job_id")
        name = json.string("name", "title").nilIfEmpty ?? String(localized: "Scheduled job")
        let scheduleObject = json.object("schedule")
        schedule = json.string("schedule_display", "cron", "expression").nilIfEmpty
            ?? scheduleObject.string("display", "expr", "run_at").nilIfEmpty
            ?? (scheduleObject.int("minutes") > 0 ? "every \(scheduleObject.int("minutes"))m" : "")
        enabled = json.bool("enabled", default: true)
        prompt = json.string("prompt", "message", "input")
        profile = json.string("profile")
        timezone = json.string("timezone").nilIfEmpty ?? TimeZone.current.identifier
        lastRun = json.string("lastRun", "last_run", "lastRunAt", "last_run_at").nilIfEmpty
        nextRun = json.string("nextRun", "next_run", "nextRunAt", "next_run_at").nilIfEmpty
    }
}

struct SkillItem: Identifiable, Hashable {
    let id: String
    var name: String
    var description: String
    var category: String
    var enabled: Bool
    var pinned: Bool
    var content: String

    init(_ json: JSON, category fallback: String = "workspace") {
        name = json.string("name", "id")
        category = json.string("category", "scope").nilIfEmpty ?? fallback
        id = "\(category)/\(name)"
        description = json.string("description", "summary")
        enabled = json.bool("enabled", default: true)
        pinned = json.bool("pinned")
        content = json.string("content", "markdown")
    }
}

struct PluginItem: Identifiable, Hashable {
    let id: String
    let key: String
    var name: String
    var description: String
    var enabled: Bool
    var version: String

    init(_ json: JSON) {
        key = json.string("key", "id", "name")
        id = key
        name = json.string("name", "title").nilIfEmpty ?? key
        description = json.string("description", "summary")
        enabled = json.bool("enabled") || json.string("effectiveStatus", "effective_status") == "enabled"
        version = json.string("version")
    }
}

struct MCPServer: Identifiable, Hashable {
    let id: String
    var name: String
    var command: String
    var arguments: [String]
    var url: String
    var enabled: Bool
    var status: String
    var tools: [String]

    init(_ json: JSON) {
        name = json.string("name", "id")
        id = name
        let config = json.object("raw_config")
        command = json.string("command").nilIfEmpty ?? config.string("command")
        arguments = json.strings("args").isEmpty ? config.strings("args") : json.strings("args")
        url = json.string("url").nilIfEmpty ?? config.string("url")
        enabled = json.bool("enabled", default: true)
        status = json.string("status").nilIfEmpty ?? (json.bool("connected") ? "connected" : (json.string("error").nilIfEmpty == nil ? "disconnected" : "error"))
        let toolRows = json.objects("tools").isEmpty ? json.objects("tool_details") : json.objects("tools")
        tools = toolRows.map { $0.string("name") }.filter { !$0.isEmpty }
    }
}

struct Pet: Identifiable, Hashable {
    let id: String
    var name: String
    var species: String
    var description: String
    var active: Bool
    var emoji: String

    init(_ json: JSON, active: Bool = false) {
        id = json.string("id", "key", "slug", "name")
        name = json.string("name", "title", "displayName", "display_name").nilIfEmpty ?? id
        species = json.string("species", "type", "kind")
        description = json.string("description", "summary")
        self.active = active || json.bool("active")
        emoji = json.string("emoji", "icon").nilIfEmpty ?? "🐾"
    }
}

struct Channel: Identifiable, Hashable {
    let id: String
    var enabled: Bool
    var configured: Bool
    var values: [String: String]
}

struct CurrentUser: Hashable {
    let id: Int
    let username: String
    let role: String
    let status: String
    let avatar: AvatarSpec?
}

struct Upload: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let path: String
    let mime: String
}

struct UsageBreakdown: Identifiable {
    let id: String
    let name: String
    let inputTokens: Int
    let outputTokens: Int
    let sessions: Int
    let cost: Double
    var totalTokens: Int { inputTokens + outputTokens }
}

struct UsageStats {
    let inputTokens: Int
    let outputTokens: Int
    let cacheTokens: Int
    let sessions: Int
    let cost: Double
    let models: [UsageBreakdown]
    let agents: [UsageBreakdown]
    let daily: [UsageBreakdown]
}

struct RuntimePerformance {
    let cpuPercent: Double?
    let memoryPercent: Double?
    let workerCount: Int
    let runningWorkers: Int
    let sessionCount: Int
}

struct DownloadLink: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let path: String
}

extension String {
    var nilIfEmpty: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }

    var relativeDate: String {
        guard let date = StudioTimestamp.date(from: self) else { return "" }
        return date.formatted(.relative(presentation: .named))
    }
}

extension Date {
    var chatTime: String { formatted(date: .omitted, time: .shortened) }
}
