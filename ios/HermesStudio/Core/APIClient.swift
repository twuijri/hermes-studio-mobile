import Foundation
import UniformTypeIdentifiers

enum HermesError: LocalizedError {
    case invalidServer
    case http(Int, String)
    case malformedResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidServer: String(localized: "Enter a valid Studio address")
        case let .http(code, detail): detail.isEmpty ? "HTTP \(code)" : "HTTP \(code): \(detail)"
        case .malformedResponse: String(localized: "The Studio returned an unreadable response")
        case let .server(message): message
        }
    }
}

final class APIClient: @unchecked Sendable {
    private(set) var baseURL: String
    private(set) var token: String
    private let session: URLSession

    init(baseURL: String = "", token: String = "") {
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.token = token
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = true
        self.session = URLSession(configuration: configuration)
    }

    func update(baseURL: String, token: String) {
        self.baseURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.token = token
    }

    func url(_ path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else { throw HermesError.invalidServer }
        return url
    }

    func request(_ path: String, method: String = "GET", body: Any? = nil, profile: String? = nil) async throws -> Any {
        var request = URLRequest(url: try url(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let profile, !profile.isEmpty { request.setValue(profile, forHTTPHeaderField: "X-Hermes-Profile") }
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw HermesError.malformedResponse }
        guard (200..<300).contains(http.statusCode) else {
            let detail = Self.errorDetail(data)
            throw HermesError.http(http.statusCode, detail)
        }
        guard !data.isEmpty else { return JSON() }
        return try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }

    func object(_ path: String, method: String = "GET", body: Any? = nil, profile: String? = nil) async throws -> JSON {
        let result = try await request(path, method: method, body: body, profile: profile)
        if let object = result as? JSON { return object }
        if let array = result as? [Any] { return ["data": array] }
        throw HermesError.malformedResponse
    }

    func array(_ path: String, keys: [String], profile: String? = nil) async throws -> [JSON] {
        let result = try await request(path, profile: profile)
        if let list = result as? [Any] { return list.objects }
        guard let json = result as? JSON else { return [] }
        for key in keys where json[key] != nil { return json.objects(key) }
        return json.objects("data")
    }

    func login(username: String, password: String) async throws -> String {
        let json = try await object("/api/auth/login", method: "POST", body: ["username": username, "password": password])
        guard let token = json.string("token").nilIfEmpty else { throw HermesError.server(String(localized: "Login succeeded but no token was returned")) }
        return token
    }

    func currentUser() async throws -> CurrentUser {
        let root = try await object("/api/auth/me")
        let user = root.object("user").isEmpty ? root : root.object("user")
        return CurrentUser(id: user.int("id"), username: user.string("username", "userId"), role: user.string("role").nilIfEmpty ?? "admin", status: user.string("status").nilIfEmpty ?? "active", avatar: AvatarSpec(user["avatar"]))
    }

    func profiles() async throws -> [Profile] {
        try await array("/api/hermes/profiles", keys: ["profiles"]).map(Profile.init).filter { !$0.name.isEmpty }
    }

    func agentStatuses() async throws -> [AgentRuntimeStatus] {
        try await object("/api/agents/status").objects("agents").map(AgentRuntimeStatus.init)
    }

    func codingAgents() async throws -> [CodingAgentTool] {
        try await object("/api/coding-agents").objects("tools").map(CodingAgentTool.init)
    }

    func installCodingAgent(_ id: String) async throws -> CodingAgentTool? {
        let root = try await object("/api/coding-agents/\(id.urlEncoded)/install", method: "POST")
        return root.object("tool").isEmpty ? nil : CodingAgentTool(root.object("tool"))
    }

    func checkCodingAgentUpdate(_ id: String) async throws -> (tool: CodingAgentTool?, available: Bool, latest: String) {
        let root = try await object("/api/coding-agents/\(id.urlEncoded)/check-update", method: "POST")
        return (root.object("tool").isEmpty ? nil : CodingAgentTool(root.object("tool")), root.bool("updateAvailable"), root.string("latestVersion"))
    }

    func deleteCodingAgent(_ id: String) async throws {
        _ = try await object("/api/coding-agents/\(id.urlEncoded)", method: "DELETE")
    }

    func profileRuntimes(refresh: Bool = true) async throws -> [ProfileRuntime] { try await array("/api/hermes/profiles/runtime-statuses\(refresh ? "" : "?refresh=0")", keys: ["profiles"]).map(ProfileRuntime.init) }
    func restartProfileRuntime(_ name: String) async throws { _ = try await object("/api/hermes/profiles/\(name.urlEncoded)/restart", method: "POST") }
    func setProfileAvatar(_ name: String, dataURL: String) async throws { _ = try await object("/api/hermes/profiles/\(name.urlEncoded)/avatar", method: "PUT", body: ["type": "image", "dataUrl": dataURL]) }
    func resetProfileAvatar(_ name: String) async throws { _ = try await object("/api/hermes/profiles/\(name.urlEncoded)/avatar", method: "DELETE") }
    func exportProfile(_ name: String) async throws -> Data {
        var request = URLRequest(url: try url("/api/hermes/profiles/\(name.urlEncoded)/export")); request.httpMethod = "POST"; if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request); guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw HermesError.server(String(localized: "Profile export failed")) }; return data
    }
    func importProfile(data: Data, name: String) async throws { _ = try await multipart("/api/hermes/profiles/import", data: data, name: name, mime: "application/gzip", field: "file", profile: nil) }

    func ekkoConfig() async throws -> JSON { try await object("/api/ekko/config") }
    func saveEkkoConfig(_ config: JSON) async throws { _ = try await object("/api/ekko/config", method: "PUT", body: ["config": config]) }
    func ekkoMemory(query: String = "") async throws -> [EkkoMemoryItem] { try await array("/api/ekko/memory\(query.isEmpty ? "" : "?query=\(query.urlEncoded)")", keys: ["memories"]).map(EkkoMemoryItem.init) }
    func updateEkkoMemory(_ item: EkkoMemoryItem) async throws { _ = try await object("/api/ekko/memory/\(item.id.urlEncoded)", method: "PATCH", body: ["expectedRevision": item.revision, "title": item.title, "content": item.content, "tags": item.tags]) }
    func deleteEkkoMemory(_ item: EkkoMemoryItem) async throws { _ = try await object("/api/ekko/memory/\(item.id.urlEncoded)", method: "DELETE", body: ["expectedRevision": item.revision]) }
    func ekkoSkills(query: String = "") async throws -> [EkkoSkillItem] { try await array("/api/ekko/skills\(query.isEmpty ? "" : "?query=\(query.urlEncoded)")", keys: ["skills"]).map(EkkoSkillItem.init) }
    func ekkoSkill(_ name: String) async throws -> EkkoSkillItem { EkkoSkillItem(try await object("/api/ekko/skills/\(name.urlEncoded)").object("skill")) }
    func setEkkoSkill(_ name: String, enabled: Bool) async throws { _ = try await object("/api/ekko/skills/\(name.urlEncoded)/toggle", method: "PUT", body: ["enabled": enabled]) }
    func createEkkoSkill(name: String, content: String, category: String) async throws { _ = try await object("/api/ekko/skills", method: "POST", body: ["name": name, "content": content, "category": category]) }
    func deleteEkkoSkill(_ name: String) async throws { _ = try await object("/api/ekko/skills/\(name.urlEncoded)", method: "DELETE") }
    func saveEkkoSkill(_ item: EkkoSkillItem) async throws { _ = try await object("/api/ekko/skills/\(item.name.urlEncoded)", method: "PUT", body: ["content": item.content]) }
    func importEkkoSkill(data: Data, name: String) async throws { _ = try await multipart("/api/ekko/skills/import", data: data, name: name, mime: "application/octet-stream", field: "file", profile: nil) }
    func ekkoSkillFiles(_ name: String) async throws -> [JSON] { try await array("/api/ekko/skills/\(name.urlEncoded)/files", keys: ["files"]) }
    func ekkoSkillFile(_ name: String, path: String) async throws -> String { try await object("/api/ekko/skills/\(name.urlEncoded)/file?path=\(path.urlEncoded)").string("content") }
    func ekkoExternalDirectories() async throws -> [String] { try await object("/api/ekko/skills/external-directories").array("directories").compactMap { ($0 as? String) ?? ($0 as? JSON)?.string("path") } }
    func saveEkkoExternalDirectories(_ directories: [String]) async throws { _ = try await object("/api/ekko/skills/external-directories", method: "PUT", body: ["directories": directories]) }
    func ekkoMCPServers() async throws -> [EkkoMCPItem] { try await array("/api/ekko/mcp/servers", keys: ["servers"]).map(EkkoMCPItem.init) }
    func saveEkkoMCP(_ server: EkkoMCPItem, existing: Bool) async throws { var config: JSON = ["enabled": server.enabled]; if !server.url.isEmpty { config["type"] = "streamable_http"; config["url"] = server.url } else { config["type"] = "stdio"; config["command"] = server.command; config["args"] = server.arguments }; _ = try await object(existing ? "/api/ekko/mcp/servers/\(server.name.urlEncoded)" : "/api/ekko/mcp/servers", method: existing ? "PATCH" : "POST", body: existing ? ["config": config] : ["name": server.name, "config": config]) }
    func deleteEkkoMCP(_ name: String) async throws { _ = try await object("/api/ekko/mcp/servers/\(name.urlEncoded)", method: "DELETE") }
    func testEkkoMCP(_ name: String) async throws -> [JSON] { try await object("/api/ekko/mcp/servers/\(name.urlEncoded)/test", method: "POST").objects("tools") }

    func providers(profile: String) async throws -> [ProviderSummary] { let root = try await object("/api/hermes/available-models?profile=\(profile.urlEncoded)"); return (root.objects("groups") + root.objects("allProviders")).map(ProviderSummary.init).reduce(into: []) { result, item in if !result.contains(where: { $0.id == item.id }) { result.append(item) } } }
    func refreshProviderCache() async throws { _ = try await object("/api/hermes/provider-models/cache/refresh", method: "POST") }
    func refreshProviderModels(_ id: String, confirm: Bool = false) async throws -> JSON { try await object("/api/hermes/config/providers/\(id.urlEncoded)/models/refresh", method: "POST", body: ["confirm": confirm]) }
    func testProvider(_ id: String) async throws -> JSON { try await object("/api/hermes/config/providers/\(id.urlEncoded)/editor/test", method: "POST", body: [:]) }

    static func sessionsPath(profile: String?, limit: Int = 80) -> String {
        guard let profile = profile?.trimmingCharacters(in: .whitespacesAndNewlines), !profile.isEmpty else {
            return "/api/hermes/sessions?limit=\(limit)"
        }
        return "/api/hermes/sessions?profile=\(profile.urlEncoded)&limit=\(limit)"
    }

    func sessions(profile: String? = nil) async throws -> [SessionSummary] {
        let fallbackProfile = profile?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var canonical = "/api/studio/sessions?limit=100"
        if !fallbackProfile.isEmpty { canonical += "&profile=\(fallbackProfile.urlEncoded)" }
        do {
            return try await array(canonical, keys: ["sessions"]).map { SessionSummary($0, profile: fallbackProfile) }.filter { !$0.id.isEmpty }
        } catch {
            return try await array(Self.sessionsPath(profile: profile), keys: ["sessions", "conversations"]).map { SessionSummary($0, profile: fallbackProfile) }.filter { !$0.id.isEmpty }
        }
    }

    func searchSessions(_ query: String, profile: String? = nil) async throws -> [SessionSummary] {
        var path = "/api/studio/search/sessions?q=\(query.urlEncoded)&limit=100"
        if let profile = profile?.nilIfEmpty { path += "&profile=\(profile.urlEncoded)" }
        return try await array(path, keys: ["results"]).map { SessionSummary($0, profile: profile ?? "") }
    }
    func sessionSummary(_ id: String, profile: String? = nil) async throws -> SessionSummary {
        let query = profile?.nilIfEmpty.map { "?profile=\($0.urlEncoded)" } ?? ""
        let root = try await object("/api/studio/sessions/\(id.urlEncoded)\(query)")
        return SessionSummary(root.object("session"), profile: profile ?? "")
    }

    func sessionCategories() async throws -> [SessionCategory] { try await array("/api/studio/session-categories", keys: ["categories"]).map(SessionCategory.init) }
    func createSessionCategory(_ name: String) async throws -> SessionCategory { SessionCategory(try await object("/api/studio/session-categories", method: "POST", body: ["name": name]).object("category")) }
    func renameSessionCategory(_ id: Int, name: String) async throws { _ = try await object("/api/studio/session-categories/\(id)", method: "PATCH", body: ["name": name]) }
    func deleteSessionCategory(_ id: Int) async throws { _ = try await object("/api/studio/session-categories/\(id)", method: "DELETE") }
    func setSessionCategory(_ id: String, categoryID: Int?) async throws {
        let body: JSON = ["categoryId": categoryID.map { $0 as Any } ?? NSNull()]
        _ = try await object("/api/studio/sessions/\(id.urlEncoded)/category", method: "POST", body: body)
    }
    func setSessionArchived(_ id: String, archived: Bool) async throws { _ = try await object("/api/studio/sessions/\(id.urlEncoded)/\(archived ? "archive" : "unarchive")", method: "POST") }

    func workflows(profile: String? = nil) async throws -> [WorkflowItem] {
        let query = profile?.nilIfEmpty.map { "?profile=\($0.urlEncoded)" } ?? ""
        return try await array("/api/studio/workflows\(query)", keys: ["workflows"]).map(WorkflowItem.init)
    }
    func workflowRuns(_ id: String) async throws -> [WorkflowRun] { try await array("/api/studio/workflows/\(id.urlEncoded)/runs?limit=100", keys: ["runs"]).map(WorkflowRun.init) }
    func runWorkflow(_ id: String, input: String?) async throws {
        var body: JSON = [:]
        if let input = input?.nilIfEmpty { body["input"] = input }
        _ = try await object("/api/studio/workflows/\(id.urlEncoded)/run", method: "POST", body: body)
    }
    func stopWorkflow(_ id: String, runID: String) async throws { _ = try await object("/api/studio/workflows/\(id.urlEncoded)/runs/\(runID.urlEncoded)/stop", method: "POST") }
    func deleteWorkflowRun(_ id: String, runID: String) async throws { _ = try await object("/api/studio/workflows/\(id.urlEncoded)/runs/\(runID.urlEncoded)", method: "DELETE") }
    func approveWorkflowNode(_ id: String, runID: String, node: WorkflowRunNode, approved: Bool) async throws { _ = try await object("/api/studio/workflows/\(id.urlEncoded)/runs/\(runID.urlEncoded)/nodes/\(node.nodeID.urlEncoded)/approval", method: "POST", body: ["approved": approved, "executionId": node.executionID]) }

    func conversationHistory(sessionID: String) async throws -> (messages: [Message], contextTokens: Int?) {
        let path = "/api/hermes/sessions/conversations/\(sessionID.urlEncoded)/messages?humanOnly=true"
        let root = try await object(path)
        let messages = root.objects("messages").map(Message.init)
        let raw = root["contextTokens"] ?? root["context_tokens"] ?? root["tokenCount"] ?? root["token_count"]
        let tokens = (raw as? NSNumber)?.intValue ?? Int(String(describing: raw ?? ""))
        return (messages, tokens)
    }

    func messages(sessionID: String) async throws -> [Message] {
        try await conversationHistory(sessionID: sessionID).messages
    }

    func contextLength(profile: String, provider: String, model: String) async throws -> Int {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "profile", value: profile),
            URLQueryItem(name: "provider", value: provider.nilIfEmpty),
            URLQueryItem(name: "model", value: model.nilIfEmpty),
        ].filter { $0.value != nil }
        let query = components.percentEncodedQuery ?? "profile=\(profile.urlEncoded)"
        let root = try await object("/api/hermes/sessions/context-length?\(query)", profile: profile)
        let length = root["context_length"] == nil ? root.int("contextLength") : root.int("context_length")
        guard length > 0 else { throw HermesError.malformedResponse }
        return length
    }

    func usageStats(days: Int) async throws -> UsageStats {
        let safeDays = min(365, max(1, days))
        let root: JSON
        do { root = try await object("/api/studio/usage/stats?days=\(safeDays)") }
        catch { root = try await object("/api/hermes/usage/stats?days=\(safeDays)") }
        let models = root.objects("model_usage").enumerated().map { index, item in
            let name = item.string("model", "name").nilIfEmpty ?? "Unknown"
            return UsageBreakdown(
                id: "\(name)-\(index)", name: name,
                inputTokens: item.int("input_tokens"), outputTokens: item.int("output_tokens"),
                sessions: item.int("sessions"), cost: item.double("cost")
            )
        }
        func breakdown(_ key: String, nameKeys: [String]) -> [UsageBreakdown] { root.objects(key).enumerated().map { index, item in let name = nameKeys.lazy.map { item.string($0) }.first(where: { !$0.isEmpty }) ?? "Unknown"; return UsageBreakdown(id: "\(key)-\(name)-\(index)", name: name, inputTokens: item.int("input_tokens"), outputTokens: item.int("output_tokens"), sessions: item.int("sessions"), cost: item["cost"] == nil ? item.double("estimated_cost_usd") : item.double("cost")) } }
        return UsageStats(
            inputTokens: root.int("total_input_tokens"), outputTokens: root.int("total_output_tokens"),
            cacheTokens: root.int("total_cache_read_tokens") + root.int("total_cache_write_tokens"),
            sessions: root.int("total_sessions"), cost: root.double("total_cost"), models: models,
            agents: breakdown("agent_usage", nameKeys: ["agent", "name", "family"]), daily: breakdown("daily_usage", nameKeys: ["date", "day"])
        )
    }

    func studioFiles(path: String, profile: String) async throws -> [StudioFileItem] { try await array("/api/studio/files/list?path=\(path.urlEncoded)&profile=\(profile.urlEncoded)", keys: ["entries"]).map(StudioFileItem.init) }
    func readStudioFile(_ path: String, profile: String) async throws -> String { try await object("/api/studio/files/read?path=\(path.urlEncoded)&profile=\(profile.urlEncoded)").string("content") }
    func writeStudioFile(_ path: String, content: String, profile: String) async throws { _ = try await object("/api/studio/files/write", method: "PUT", body: ["path": path, "content": content, "profile": profile]) }
    func mkdirStudioFile(_ path: String, profile: String) async throws { _ = try await object("/api/studio/files/mkdir", method: "POST", body: ["path": path, "profile": profile]) }
    func renameStudioFile(_ path: String, to newPath: String, profile: String) async throws { _ = try await object("/api/studio/files/rename", method: "POST", body: ["oldPath": path, "newPath": newPath, "profile": profile]) }
    func copyStudioFile(_ path: String, to newPath: String, profile: String) async throws { _ = try await object("/api/studio/files/copy", method: "POST", body: ["srcPath": path, "destPath": newPath, "profile": profile]) }
    func deleteStudioFile(_ path: String, recursive: Bool, profile: String) async throws { _ = try await object("/api/studio/files/delete", method: "DELETE", body: ["path": path, "recursive": recursive, "profile": profile]) }
    func uploadStudioFile(data: Data, name: String, mime: String, path: String, profile: String) async throws { _ = try await multipart("/api/studio/files/upload?path=\(path.urlEncoded)&profile=\(profile.urlEncoded)", data: data, name: name, mime: mime, field: "file", profile: profile) }
    func studioFileURL(_ path: String, profile: String) -> URL? { try? url("/api/studio/files/download?path=\(path.urlEncoded)&profile=\(profile.urlEncoded)&token=\(token.urlEncoded)") }
    func logFiles() async throws -> [StudioLogFile] { try await array("/api/studio/logs", keys: ["files"]).map(StudioLogFile.init) }
    func logEntries(_ name: String, text: String = "", level: String = "") async throws -> [StudioLogEntry] { var path = "/api/studio/logs/\(name.urlEncoded)?lines=1000"; if !text.isEmpty { path += "&text=\(text.urlEncoded)" }; if !level.isEmpty { path += "&level=\(level.urlEncoded)" }; return try await array(path, keys: ["entries"]).map(StudioLogEntry.init) }
    func appRelay(_ action: String = "status", method: String = "GET", body: JSON? = nil) async throws -> AppRelayInfo { AppRelayInfo(try await object("/api/app-relay/\(action)", method: method, body: body).object("relay")) }
    func appConnections() async throws -> [AppConnectionItem] { try await array("/api/app-connections", keys: ["connections"]).map(AppConnectionItem.init) }
    func deleteAppConnection(_ id: Int) async throws { _ = try await object("/api/app-connections/\(id)", method: "DELETE") }
    func appAuthorization(cloud: Bool, refresh: Bool = false, route: String = "official") async throws -> JSON { try await object("/api/app-connections/authorization-codes/\(cloud ? "cloud" : "lan")", method: "POST", body: cloud ? ["refresh": refresh, "route": route] : nil) }
    func devices(scan: Bool = false) async throws -> [StudioDevice] { try await object("/api/devices\(scan ? "/scan" : "")", method: scan ? "POST" : "GET").objects("devices").map(StudioDevice.init) }
    func deviceAction(_ id: String, action: String) async throws { _ = try await object("/api/devices/\(id.urlEncoded)/\(action)", method: "POST") }
    func devicePairingLink() async throws -> JSON { try await object("/api/devices/pairing-link") }
    func requestDevice(url: String) async throws { _ = try await object("/api/devices/manual-request", method: "POST", body: ["url": url]) }
    func peerConnections() async throws -> [PeerConnection] { try await array("/api/devices/peer-connections", keys: ["connections"]).map(PeerConnection.init) }
    func disconnectPeer(_ id: String) async throws { _ = try await object("/api/devices/peer-connections/\(id.urlEncoded)/disconnect", method: "POST") }
    func providerAuthStatus(_ provider: String) async throws -> JSON { try await object("/api/hermes/auth/\(provider.urlEncoded)/status") }
    func startProviderAuth(_ provider: String) async throws -> JSON { try await object("/api/hermes/auth/\(provider.urlEncoded)/start", method: "POST") }
    func pollProviderAuth(_ provider: String, sessionID: String) async throws -> JSON { try await object("/api/hermes/auth/\(provider.urlEncoded)/poll/\(sessionID.urlEncoded)") }
    func submitProviderAuth(_ provider: String, sessionID: String, code: String) async throws -> JSON { try await object("/api/hermes/auth/\(provider.urlEncoded)/submit/\(sessionID.urlEncoded)", method: "POST", body: ["code": code]) }

    func runtimePerformance() async throws -> RuntimePerformance {
        let root = try await object("/api/hermes/performance/runtime")
        let system = root.object("system"), bridge = root.object("bridge"), sessions = root.object("sessions")
        let workers = bridge.objects("workers")
        return RuntimePerformance(
            cpuPercent: system["cpuPercent"] == nil ? nil : system.double("cpuPercent"),
            memoryPercent: system["memoryPercent"] == nil ? nil : system.double("memoryPercent"),
            workerCount: workers.count, runningWorkers: workers.filter { $0.bool("running") }.count,
            sessionCount: sessions.int("total")
        )
    }

    func renameSession(_ id: String, title: String) async throws { _ = try await object("/api/hermes/sessions/\(id.urlEncoded)/rename", method: "POST", body: ["title": title]) }
    func deleteSession(_ id: String) async throws { _ = try await object("/api/hermes/sessions/\(id.urlEncoded)", method: "DELETE") }
    func setSessionModel(_ id: String, model: String, provider: String?) async throws {
        var body: JSON = ["model": model]; if let provider, !provider.isEmpty { body["provider"] = provider }
        _ = try await object("/api/hermes/sessions/\(id.urlEncoded)/model", method: "POST", body: body)
    }

    func models(profile: String) async throws -> [ModelOption] {
        let root = try await object("/api/hermes/available-models?profile=\(profile.urlEncoded)")
        var values = root.objects("models")
        if values.isEmpty, let strings = root["models"] as? [String] { values = strings.map { ["id": $0, "name": $0] } }
        if values.isEmpty {
            for group in root.objects("groups") + root.objects("allProviders") {
                let provider = group.string("provider", "name", "label")
                for raw in group.array("models") {
                    if let id = raw as? String, id != "*" { values.append(["id": id, "name": id, "provider": provider]) }
                    else if var model = raw as? JSON { model["provider"] = model.string("provider").nilIfEmpty ?? provider; values.append(model) }
                }
            }
        }
        return values.map(ModelOption.init).filter { !$0.id.isEmpty }
    }

    func setDefaultModel(profile: String, model: String, provider: String?) async throws {
        var body: JSON = ["default": model]; if let provider, !provider.isEmpty { body["provider"] = provider }
        _ = try await object("/api/hermes/config/model?profile=\(profile.urlEncoded)", method: "PUT", body: body, profile: profile)
    }

    func updateProviderKey(profile: String, provider: String, key: String) async throws {
        _ = try await object("/api/hermes/config/providers/\(provider.urlEncoded)?profile=\(profile.urlEncoded)", method: "PUT", body: ["api_key": key], profile: profile)
    }

    func createProfile(_ name: String) async throws { _ = try await object("/api/hermes/profiles", method: "POST", body: ["name": name]) }
    func cloneProfile(_ name: String) async throws { _ = try await object("/api/hermes/profiles", method: "POST", body: ["name": name, "clone": true]) }
    func activateProfile(_ name: String) async throws { _ = try await object("/api/hermes/profiles/active", method: "PUT", body: ["name": name]) }
    func renameProfile(_ name: String, to newName: String) async throws { _ = try await object("/api/hermes/profiles/\(name.urlEncoded)/rename", method: "POST", body: ["new_name": newName]) }
    func deleteProfile(_ name: String) async throws { _ = try await object("/api/hermes/profiles/\(name.urlEncoded)", method: "DELETE") }
    func restartGateway(profile: String) async throws { _ = try await object("/api/hermes/profiles/\(profile.urlEncoded)/gateway/restart", method: "POST") }

    func rooms() async throws -> [Room] { try await array("/api/hermes/group-chat/rooms", keys: ["rooms"]).map(Room.init).filter { !$0.id.isEmpty } }
    func room(_ id: String) async throws -> (Room, [RoomMessage]) {
        let root = try await object("/api/hermes/group-chat/rooms/\(id.urlEncoded)?limit=80&offset=0")
        let roomJSON = root.object("room").isEmpty ? root : root.object("room")
        return (Room(roomJSON), root.objects("messages").map(RoomMessage.init))
    }
    func createRoom(name: String, inviteCode: String, agents: [String]) async throws -> Room {
        let body: JSON = ["name": name, "inviteCode": inviteCode, "agents": agents.map { ["profile": $0] }]
        let root = try await object("/api/hermes/group-chat/rooms", method: "POST", body: body)
        return Room(root.object("room"))
    }
    func deleteRoom(_ id: String) async throws { _ = try await object("/api/hermes/group-chat/rooms/\(id.urlEncoded)", method: "DELETE") }
    func addRoomAgent(_ id: String, profile: String) async throws { _ = try await object("/api/hermes/group-chat/rooms/\(id.urlEncoded)/agents", method: "POST", body: ["profile": profile]) }

    func boards() async throws -> [KanbanBoard] {
        var rows = try await array("/api/hermes/kanban/boards", keys: ["boards"])
        if rows.isEmpty { rows = [["id": "default", "name": String(localized: "Default")]] }
        return rows.map(KanbanBoard.init)
    }
    func kanbanTasks(board: String) async throws -> [KanbanTask] { try await array("/api/hermes/kanban?board=\(board.urlEncoded)", keys: ["tasks", "items"]).map(KanbanTask.init) }
    func createTask(board: String, title: String, description: String, priority: String) async throws {
        let numericPriority = priority == "high" ? 3 : (priority == "low" ? 1 : 2)
        _ = try await object("/api/hermes/kanban?board=\(board.urlEncoded)", method: "POST", body: ["title": title, "body": description, "priority": numericPriority, "triage": true, "skills": []])
    }
    func moveTasks(board: String, ids: [String], status: String) async throws { _ = try await object("/api/hermes/kanban/tasks/bulk?board=\(board.urlEncoded)", method: "POST", body: ["ids": ids, "status": status]) }
    func assignTask(board: String, id: String, profile: String?) async throws {
        let body: JSON = ["profile": profile ?? ""]
        _ = try await object("/api/hermes/kanban/\(id.urlEncoded)/assign?board=\(board.urlEncoded)", method: "POST", body: body)
    }
    func commentTask(board: String, id: String, comment: String) async throws { _ = try await object("/api/hermes/kanban/\(id.urlEncoded)/comments?board=\(board.urlEncoded)", method: "POST", body: ["body": comment]) }

    func cronJobs(profile: String) async throws -> [CronJob] {
        try await array("/api/hermes/jobs?include_disabled=true", keys: ["jobs"], profile: profile).map(CronJob.init)
    }
    func setCronEnabled(_ id: String, enabled: Bool, profile: String) async throws { _ = try await object("/api/hermes/jobs/\(id.urlEncoded)/\(enabled ? "resume" : "pause")", method: "POST", profile: profile) }
    func runCron(_ id: String, profile: String) async throws { _ = try await object("/api/hermes/jobs/\(id.urlEncoded)/run", method: "POST", profile: profile) }
    func deleteCron(_ id: String, profile: String) async throws { _ = try await object("/api/hermes/jobs/\(id.urlEncoded)", method: "DELETE", profile: profile) }
    func saveCron(id: String?, name: String, schedule: String, prompt: String, profile: String, enabled: Bool) async throws {
        let body: JSON = ["name": name, "schedule": schedule, "prompt": prompt, "profile": profile, "enabled": enabled, "timezone": TimeZone.current.identifier]
        let path = id.map { "/api/hermes/jobs/\($0.urlEncoded)" } ?? "/api/hermes/jobs"
        _ = try await object(path, method: id == nil ? "POST" : "PATCH", body: body, profile: profile)
    }

    func skills(profile: String) async throws -> [SkillItem] {
        let root = try await object("/api/hermes/skills?profile=\(profile.urlEncoded)&target=all", profile: profile)
        var result = root.objects("skills").map { SkillItem($0) }
        if result.isEmpty {
            for category in root.objects("categories") {
                let categoryName = category.string("name", "category").nilIfEmpty ?? "workspace"
                result += category.objects("skills").map { SkillItem($0, category: categoryName) }
            }
        }
        if result.isEmpty {
            for (category, raw) in root where raw is [Any] { result += (raw as? [Any] ?? []).objects.map { SkillItem($0, category: category) } }
        }
        return result
    }
    func skill(category: String, name: String, profile: String) async throws -> SkillItem {
        let result = try await object("/api/hermes/skills/\(category.urlEncoded)/\(name.urlEncoded)", profile: profile)
        return SkillItem(["name": name, "category": category, "content": result.string("content"), "enabled": true], category: category)
    }
    func saveSkill(_ skill: SkillItem, profile: String) async throws { _ = try await object("/api/hermes/skills/\(skill.category.urlEncoded)/\(skill.name.urlEncoded)", method: "PUT", body: ["content": skill.content], profile: profile) }
    func toggleSkill(_ skill: SkillItem, profile: String) async throws { _ = try await object("/api/hermes/skills/toggle", method: "PUT", body: ["name": skill.name, "enabled": !skill.enabled], profile: profile) }
    func pinSkill(_ skill: SkillItem, profile: String) async throws { _ = try await object("/api/hermes/skills/pin", method: "PUT", body: ["name": skill.name, "pinned": !skill.pinned], profile: profile) }
    func deleteSkill(_ skill: SkillItem, profile: String) async throws { _ = try await object("/api/hermes/skills/\(skill.category.urlEncoded)/\(skill.name.urlEncoded)", method: "DELETE", profile: profile) }

    func plugins() async throws -> [PluginItem] { try await array("/api/hermes/plugins", keys: ["plugins"]).map(PluginItem.init) }
    func setPlugin(_ plugin: PluginItem, enabled: Bool) async throws { _ = try await object("/api/hermes/plugins/\(plugin.key.urlEncoded)/\(enabled ? "enable" : "disable")", method: "POST") }

    func mcpServers() async throws -> [MCPServer] { try await array("/api/hermes/mcp/servers", keys: ["servers"]).map(MCPServer.init) }
    func saveMCP(name: String, command: String, arguments: [String], url: String, enabled: Bool, existing: Bool) async throws {
        var config: JSON = ["enabled": enabled]
        if !url.isEmpty { config["transport"] = "http"; config["url"] = url }
        else { config["transport"] = "stdio"; config["command"] = command; config["args"] = arguments }
        let body: JSON = existing ? ["config": config] : ["name": name, "config": config]
        _ = try await object(existing ? "/api/hermes/mcp/servers/\(name.urlEncoded)" : "/api/hermes/mcp/servers", method: existing ? "PATCH" : "POST", body: body)
    }
    func testMCP(_ name: String) async throws -> JSON { try await object("/api/hermes/mcp/servers/\(name.urlEncoded)/test", method: "POST") }
    func reloadMCP(_ name: String) async throws { _ = try await object("/api/hermes/mcp/reload?server=\(name.urlEncoded)", method: "POST") }
    func deleteMCP(_ name: String) async throws { _ = try await object("/api/hermes/mcp/servers/\(name.urlEncoded)", method: "DELETE") }

    func petManifest() async throws -> [Pet] { try await array("/api/hermes/petdex/manifest", keys: ["pets", "manifest"]).map { Pet($0) } }
    func activePets() async throws -> [Pet] {
        let result = try await object("/api/hermes/pets/active")
        let pet = result.object("pet")
        return pet.isEmpty ? [] : [Pet(pet, active: pet.bool("enabled", default: true))]
    }
    func adoptPet(_ id: String, profile: String) async throws { _ = try await object("/api/hermes/pets/adopt", method: "POST", body: ["slug": id]) }
    func setPet(_ id: String, profile: String, active: Bool) async throws { _ = try await object("/api/hermes/pets/active", method: "PATCH", body: ["enabled": active]) }

    func pendingSkillWrites(profile: String) async throws -> [PendingSkillWrite] {
        try await object("/api/hermes/write-gate/pending", profile: profile).objects("records")
            .filter { $0.string("subsystem") == "skills" }
            .map(PendingSkillWrite.init)
            .filter { !$0.id.isEmpty }
    }

    func resolvePendingSkillWrite(_ id: String, approve: Bool, profile: String) async throws {
        let action = approve ? "approve" : "reject"
        _ = try await object("/api/hermes/write-gate/pending/skills/\(id.urlEncoded)/\(action)", method: "POST", profile: profile)
    }

    func config(profile: String, section: String? = nil) async throws -> JSON {
        var path = "/api/hermes/config?profile=\(profile.urlEncoded)"
        if let section { path += "&section=\(section.urlEncoded)" }
        return try await object(path, profile: profile)
    }
    func updateConfig(profile: String, section: String, values: JSON, restart: Bool = false) async throws {
        let body: JSON = ["section": section, "values": values, "restart": restart]
        _ = try await object("/api/hermes/config?profile=\(profile.urlEncoded)", method: "PUT", body: body, profile: profile)
    }
    func updateCredentials(profile: String, platform: String, values: JSON) async throws {
        _ = try await object("/api/hermes/config/credentials?profile=\(profile.urlEncoded)", method: "PUT", body: ["platform": platform, "values": values], profile: profile)
    }
    func clearCredentials(profile: String, platform: String) async throws { _ = try await object("/api/hermes/config/credentials/\(platform.urlEncoded)?profile=\(profile.urlEncoded)", method: "DELETE", profile: profile) }

    func weixinQrCode(profile: String) async throws -> (id: String, url: URL) {
        let result = try await object("/api/hermes/weixin/qrcode", profile: profile)
        guard let id = result.string("qrcode").nilIfEmpty,
              let url = URL(string: result.string("qrcode_url")) else {
            throw HermesError.malformedResponse
        }
        return (id, url)
    }

    func weixinQrStatus(profile: String, code: String) async throws -> JSON {
        try await object("/api/hermes/weixin/qrcode/status?qrcode=\(code.urlEncoded)", profile: profile)
    }

    func saveWeixinCredentials(profile: String, status: JSON) async throws {
        let accountID = status.string("account_id")
        let issuedToken = status.string("token")
        guard !accountID.isEmpty, !issuedToken.isEmpty else { throw HermesError.malformedResponse }
        var body: JSON = ["account_id": accountID, "token": issuedToken]
        if let baseURL = status.string("base_url").nilIfEmpty { body["base_url"] = baseURL }
        _ = try await object("/api/hermes/weixin/save", method: "POST", body: body, profile: profile)
    }

    func changePassword(current: String, new: String) async throws { _ = try await object("/api/auth/change-password", method: "POST", body: ["currentPassword": current, "newPassword": new]) }
    func changeUsername(currentPassword: String, newUsername: String) async throws { _ = try await object("/api/auth/change-username", method: "POST", body: ["currentPassword": currentPassword, "newUsername": newUsername]) }
    func updateAvatar(dataURL: String) async throws {
        let data = try JSONSerialization.data(withJSONObject: ["type": "image", "dataUrl": dataURL])
        _ = try await object("/api/auth/avatar", method: "PUT", body: ["avatar": String(data: data, encoding: .utf8) ?? ""])
    }
    func resetAvatar() async throws { _ = try await object("/api/auth/avatar", method: "PUT", body: ["avatar": ["type": "default"]]) }

    func upload(data: Data, name: String, mime: String, profile: String) async throws -> Upload {
        let result = try await multipart("/upload?profile=\(profile.urlEncoded)", data: data, name: name, mime: mime, field: "file", profile: profile)
        let item = result.object("file").isEmpty ? result : result.object("file")
        return Upload(name: item.string("name", "filename").nilIfEmpty ?? name, path: item.string("path", "filePath", "url"), mime: item.string("mime", "media_type", "type").nilIfEmpty ?? mime)
    }

    func transcribe(data: Data, name: String, mime: String, profile: String) async throws -> String {
        let settings = try await object("/api/hermes/stt/settings?profile=\(profile.urlEncoded)", profile: profile)
        let provider = settings.string("activeProvider")
        guard !provider.isEmpty, provider != "browser" else {
            throw HermesError.server(String(localized: "Configure a server-backed speech recognition provider in Studio first"))
        }
        let result = try await multipart(
            "/api/hermes/stt/transcribe?profile=\(profile.urlEncoded)",
            data: data,
            name: name,
            mime: mime,
            field: "audio",
            fields: ["provider": provider],
            profile: profile
        )
        return result.string("text", "transcript")
    }

    func synthesize(text: String, profile: String) async throws -> Data {
        var request = URLRequest(url: try url("/api/hermes/tts/synthesize"))
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        // Let Studio negotiate the active provider's native audio format.
        request.setValue("audio/*", forHTTPHeaderField: "Accept")
        request.setValue(profile, forHTTPHeaderField: "X-Hermes-Profile")
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: ["text": text, "options": [:]])
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw HermesError.http((response as? HTTPURLResponse)?.statusCode ?? -1, Self.errorDetail(data))
        }
        guard !data.isEmpty else { throw HermesError.malformedResponse }
        let contentType = http.value(forHTTPHeaderField: "Content-Type")?.lowercased() ?? ""
        if contentType.contains("json") || data.first == Character("{").asciiValue {
            throw HermesError.server(Self.errorDetail(data))
        }
        return data
    }

    func runChatREST(profile: String, sessionID: String, input: String, attachments: [Upload], reasoningEffort: String?, model: String?, provider: String?) async throws -> (String, String) {
        let content: Any
        if attachments.isEmpty { content = input }
        else {
            var blocks: [JSON] = input.isEmpty ? [] : [["type": "text", "text": input]]
            blocks += attachments.map { ["type": $0.mime.hasPrefix("image/") ? "image" : "file", "name": $0.name, "path": $0.path, "media_type": $0.mime] }
            content = blocks
        }
        var body: JSON = ["input": content, "profile": profile, "session_id": sessionID]
        if let reasoningEffort, !reasoningEffort.isEmpty { body["reasoning_effort"] = reasoningEffort }
        if let model, !model.isEmpty { body["model"] = model }
        if let provider, !provider.isEmpty { body["provider"] = provider }
        let result = try await object("/api/chat-run/runs", method: "POST", body: body, profile: profile)
        return (result.string("output", "message", "text"), result.string("reasoning", "thinking"))
    }

    private func multipart(_ path: String, data: Data, name: String, mime: String, field: String, fields: [String: String] = [:], profile: String?) async throws -> JSON {
        let boundary = "HermesBoundary\(UUID().uuidString)"
        var body = Data()
        for (key, value) in fields {
            body.append("--\(boundary)\r\n")
            body.append("Content-Disposition: form-data; name=\"\(key.replacingOccurrences(of: "\"", with: ""))\"\r\n\r\n")
            body.append("\(value)\r\n")
        }
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(field)\"; filename=\"\(name.replacingOccurrences(of: "\"", with: ""))\"\r\n")
        body.append("Content-Type: \(mime)\r\n\r\n")
        body.append(data); body.append("\r\n--\(boundary)--\r\n")
        var request = URLRequest(url: try url(path)); request.httpMethod = "POST"; request.httpBody = body
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let profile { request.setValue(profile, forHTTPHeaderField: "X-Hermes-Profile") }
        let (responseData, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw HermesError.http(code, Self.errorDetail(responseData))
        }
        guard let json = try JSONSerialization.jsonObject(with: responseData) as? JSON else { throw HermesError.malformedResponse }
        return json
    }

    func downloadURL(path: String, name: String, profile: String) -> URL? {
        var components = URLComponents(string: baseURL + "/api/hermes/download")
        components?.queryItems = [URLQueryItem(name: "path", value: path), URLQueryItem(name: "name", value: name), URLQueryItem(name: "profile", value: profile), URLQueryItem(name: "token", value: token)]
        return components?.url
    }

    func logoData() async -> Data? {
        guard let url = try? url("/logo.png") else { return nil }
        var request = URLRequest(url: url); if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        return try? await session.data(for: request).0
    }

    private static func errorDetail(_ data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? JSON { return json.string("error", "message", "detail") }
        return String(data: data, encoding: .utf8)?.prefix(300).description ?? ""
    }
}

private extension Data {
    mutating func append(_ string: String) { if let data = string.data(using: .utf8) { append(data) } }
}

extension String {
    var urlEncoded: String { addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?#/"))) ?? self }
}
