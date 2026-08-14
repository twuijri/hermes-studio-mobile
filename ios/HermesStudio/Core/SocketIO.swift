import Foundation

enum LiveRunEvent {
    case started(Date)
    case text(String)
    case reasoning(String)
    case tool(id: String, name: String, detail: String?, status: ToolStatus, duration: Double?)
    case completed(output: String, reasoning: String)
    case requiresAction(String)
    case failed(String, retryable: Bool)
}

enum LiveRoomEvent {
    case connected
    case message(RoomMessage)
    case disconnected
    case failed(String)
}

private final class ChatReconnectTask: @unchecked Sendable {
    var value: Task<Void, Never>?
}

final class SocketIOConnection: @unchecked Sendable {
    private let baseURL: String
    private let token: String
    private let namespace: String
    private let profile: String?
    private var socket: URLSessionWebSocketTask?
    private var readTask: Task<Void, Never>?
    private var onPacket: ((String) -> Void)?
    private(set) var isConnected = false

    init(baseURL: String, token: String, namespace: String, profile: String? = nil) {
        self.baseURL = baseURL; self.token = token; self.namespace = namespace; self.profile = profile
    }

    func connect(onPacket: @escaping (String) -> Void) {
        close()
        self.onPacket = onPacket
        guard var components = URLComponents(string: baseURL) else { onPacket("__error__:invalid server"); return }
        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/socket.io/"
        components.queryItems = [URLQueryItem(name: "EIO", value: "4"), URLQueryItem(name: "transport", value: "websocket")] + (profile.map { [URLQueryItem(name: "profile", value: $0)] } ?? [])
        guard let url = components.url else { onPacket("__error__:invalid server"); return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let task = URLSession(configuration: .default).webSocketTask(with: request)
        socket = task; task.resume()
        readTask = Task { [weak self] in await self?.readLoop() }
    }

    func emit(_ event: String, payload: Any, ackID: Int? = nil) {
        guard let data = try? JSONSerialization.data(withJSONObject: [event, payload]), let json = String(data: data, encoding: .utf8) else { return }
        let ack = ackID.map(String.init) ?? ""
        send("42\(namespace),\(ack)\(json)")
    }

    func close() {
        readTask?.cancel(); readTask = nil
        socket?.cancel(with: .goingAway, reason: nil); socket = nil
        isConnected = false
        onPacket = nil
    }

    private func send(_ text: String) { socket?.send(.string(text)) { [weak self] error in if let error { self?.onPacket?("__error__:\(error.localizedDescription)") } } }

    private func readLoop() async {
        while !Task.isCancelled, let socket {
            do {
                let message = try await socket.receive()
                let text: String
                switch message { case let .string(value): text = value; case let .data(data): text = String(data: data, encoding: .utf8) ?? ""; @unknown default: text = "" }
                for packet in text.components(separatedBy: "\u{001e}") { process(packet) }
            } catch {
                if !Task.isCancelled { onPacket?("__error__:\(error.localizedDescription)") }
                break
            }
        }
    }

    private func process(_ packet: String) {
        if packet == "2" || packet.hasPrefix("2") && packet.dropFirst().allSatisfy(\.isNumber) { send("3" + String(packet.dropFirst())); return }
        if packet.hasPrefix("0") {
            let auth = token.isEmpty ? JSON() : ["token": token]
            let data = (try? JSONSerialization.data(withJSONObject: auth)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            send("40\(namespace),\(data)")
            return
        }
        if packet.hasPrefix("40\(namespace)") { isConnected = true; onPacket?("__connected__"); return }
        if packet.hasPrefix("41\(namespace)") { isConnected = false; onPacket?("__disconnected__"); return }
        onPacket?(packet)
    }
}

final class ChatSocket: @unchecked Sendable {
    private var connection: SocketIOConnection?

    func abort(sessionID: String) { connection?.emit("abort", payload: ["session_id": sessionID]) }
    func close() { connection?.close(); connection = nil }

    func run(baseURL: String, token: String, profile: String, sessionID: String, input: String, attachments: [Upload], reasoningEffort: String?, model: String?, provider: String?) -> AsyncStream<LiveRunEvent> {
        close()
        return AsyncStream { continuation in
            var payload: JSON = ["input": Self.content(input, attachments), "profile": profile, "session_id": sessionID]
            if let reasoningEffort, !reasoningEffort.isEmpty { payload["reasoning_effort"] = reasoningEffort }
            if let model, !model.isEmpty { payload["model"] = model }
            if let provider, !provider.isEmpty { payload["provider"] = provider }
            let live = SocketIOConnection(baseURL: baseURL, token: token, namespace: "/chat-run", profile: profile)
            self.connection = live
            var started = false
            var submitted = false
            var terminal = false
            var reconnectAttempt = 0
            let retryTask = ChatReconnectTask()
            var handlePacket: ((String) -> Void)!

            func scheduleReconnect() {
                guard !terminal, submitted, retryTask.value == nil else { return }
                let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0)
                reconnectAttempt += 1
                retryTask.value = Task {
                    try? await Task.sleep(for: .seconds(delay))
                    guard !Task.isCancelled, !terminal else { return }
                    retryTask.value = nil
                    live.connect(onPacket: handlePacket)
                }
            }

            func finish() {
                guard !terminal else { return }
                terminal = true
                retryTask.value?.cancel()
                continuation.finish()
                live.close()
            }

            handlePacket = { packet in
                if packet == "__connected__" {
                    reconnectAttempt = 0
                    if submitted {
                        live.emit("resume", payload: ["session_id": sessionID, "profile": profile])
                    } else {
                        submitted = true
                        live.emit("run", payload: payload)
                    }
                    return
                }
                if packet == "__disconnected__" || packet.hasPrefix("__error__:") {
                    if submitted {
                        scheduleReconnect()
                    } else {
                        let message = packet.hasPrefix("__error__:") ? String(packet.dropFirst(10)) : String(localized: "Connection dropped")
                        continuation.yield(.failed(message, retryable: !started))
                        finish()
                    }
                    return
                }
                guard let (event, json) = Self.event(packet, namespace: "/chat-run") else { return }
                switch event {
                case "resumed":
                    if json.bool("isWorking") {
                        started = true
                    } else if let completion = Self.completion(fromResume: json) {
                        continuation.yield(.completed(output: completion.output, reasoning: completion.reasoning))
                        finish()
                    } else {
                        continuation.yield(.failed(String(localized: "Run failed"), retryable: false))
                        finish()
                    }
                case "run.started": started = true; continuation.yield(.started(.now))
                case "message.delta":
                    let delta = json.string("delta", "text"); if !delta.isEmpty { started = true; continuation.yield(.text(delta)) }
                case "reasoning.delta", "thinking.delta":
                    let delta = json.string("delta", "text"); if !delta.isEmpty { started = true; continuation.yield(.reasoning(delta)) }
                case "tool.started", "tool.completed", "tool.failed":
                    started = true
                    let id = json.string("tool_call_id", "call_id", "id")
                    let name = json.string("tool", "name", "tool_name", "function_name").nilIfEmpty ?? "tool"
                    let detail = Self.toolDetail(json)
                    let status: ToolStatus = event == "tool.started" ? .running : (event == "tool.failed" || json.bool("error") ? .error : .done)
                    continuation.yield(.tool(id: id.isEmpty ? "\(name)-\(UUID().uuidString)" : id, name: name, detail: detail, status: status, duration: json["duration_seconds"] == nil ? nil : json.double("duration_seconds")))
                case "run.completed": continuation.yield(.completed(output: json.string("output"), reasoning: json.string("reasoning"))); finish()
                case "approval.requested", "clarify.requested": continuation.yield(.requiresAction(event)); finish()
                case "run.failed": continuation.yield(.failed(json.string("error", "message").nilIfEmpty ?? String(localized: "Run failed"), retryable: false)); finish()
                default: break
                }
            }
            live.connect(onPacket: handlePacket)
            continuation.onTermination = { [weak self] _ in retryTask.value?.cancel(); self?.close() }
        }
    }

    /// Recovers the final assistant message persisted while the phone was
    /// changing networks or temporarily suspended.
    static func completion(fromResume json: JSON) -> (output: String, reasoning: String)? {
        guard !json.bool("isWorking") else { return nil }
        let messages = json.objects("messages")
        guard let lastUser = messages.lastIndex(where: { ["user", "command"].contains($0.string("role")) }),
              lastUser + 1 < messages.count
        else { return nil }
        for message in messages[(lastUser + 1)...].reversed() where message.string("role") == "assistant" {
            let output = message.string("display_content", "content")
            if !output.isEmpty { return (output, message.string("reasoning")) }
        }
        return nil
    }

    private static func content(_ input: String, _ attachments: [Upload]) -> Any {
        guard !attachments.isEmpty else { return input }
        var blocks: [JSON] = []
        if !input.isEmpty { blocks.append(["type": "text", "text": input]) }
        blocks += attachments.map { ["type": $0.mime.hasPrefix("image/") ? "image" : "file", "name": $0.name, "path": $0.path, "media_type": $0.mime] }
        return blocks
    }

    static func event(_ packet: String, namespace: String) -> (String, JSON)? {
        guard packet.hasPrefix("42\(namespace),"), let bracket = packet.firstIndex(of: "[") else { return nil }
        let jsonText = String(packet[bracket...])
        guard let data = jsonText.data(using: .utf8), let array = try? JSONSerialization.jsonObject(with: data) as? [Any], let event = array.first as? String else { return nil }
        return (event, array.count > 1 ? (array[1] as? JSON ?? [:]) : [:])
    }

    private static func toolDetail(_ json: JSON) -> String? {
        if let detail = json.string("preview", "detail").nilIfEmpty { return detail.replacingOccurrences(of: "\n", with: " ") }
        if let object = json["arguments"] as? JSON {
            for key in ["command", "cmd", "path", "file_path", "query", "url", "prompt"] { if let value = object.string(key).nilIfEmpty { return value.replacingOccurrences(of: "\n", with: " ") } }
            if let data = try? JSONSerialization.data(withJSONObject: object), let text = String(data: data, encoding: .utf8) { return text }
        }
        return (json["arguments"] as? String)?.replacingOccurrences(of: "\n", with: " ")
    }
}

final class GroupSocket: @unchecked Sendable {
    private var connection: SocketIOConnection?
    private var roomID: String?

    func join(baseURL: String, token: String, roomID: String, memberName: String) -> AsyncStream<LiveRoomEvent> {
        close(); self.roomID = roomID
        return AsyncStream { continuation in
            let live = SocketIOConnection(baseURL: baseURL, token: token, namespace: "/group-chat")
            self.connection = live
            live.connect { packet in
                if packet == "__connected__" { live.emit("join", payload: ["roomId": roomID, "name": memberName], ackID: 0); continuation.yield(.connected); return }
                if packet == "__disconnected__" { continuation.yield(.disconnected); continuation.finish(); return }
                if packet.hasPrefix("__error__:") { continuation.yield(.failed(String(packet.dropFirst(10)))); continuation.finish(); return }
                guard let (event, json) = ChatSocket.event(packet, namespace: "/group-chat") else { return }
                if event == "message", !json.string("content").isEmpty { continuation.yield(.message(RoomMessage(json))) }
            }
            continuation.onTermination = { [weak self] _ in self?.close() }
        }
    }

    func post(_ text: String, senderName: String) -> Bool {
        guard let connection, connection.isConnected, let roomID else { return false }
        connection.emit("message", payload: ["roomId": roomID, "content": text, "senderName": senderName], ackID: 1)
        return true
    }
    func close() { connection?.close(); connection = nil; roomID = nil }
}
