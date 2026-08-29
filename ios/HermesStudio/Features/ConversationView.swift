import SwiftUI
import UniformTypeIdentifiers

struct ConversationView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    let session: SessionSummary
    @State private var lines: [ChatLine] = []
    @State private var input = ""
    @State private var attachments: [Upload] = []
    @State private var loading = true
    @State private var sending = false
    @State private var importing = false
    @State private var uploading = false
    @State private var models: [ModelOption] = []
    @State private var selectedModel = ""
    @State private var selectedProvider = ""
    @State private var contextTokens = 0
    @State private var contextWindow = 0
    @State private var loadingContext = false
    @State private var socket = ChatSocket()
    @StateObject private var recorder = VoiceRecorder()
    @StateObject private var speechPlayer = SpeechPlayer()
    @State private var voiceReplyPending = false
    @State private var bottomVisible = true
    @State private var actionLine: ChatLine?
    @State private var replyingTo: ChatLine?
    @State private var composerExpanded = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { reader in
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            if loading { ProgressView().padding(.top, 40) }
                            ForEach(lines) { line in MessageBubble(line: line, profile: profile, api: store.api, sessionProfile: session.profile) { actionLine = line }.id(line.id) }
                            Color.clear.frame(height: 1).id("bottom")
                                .onAppear { bottomVisible = true }
                                .onDisappear { bottomVisible = false }
                        }.padding(.horizontal, 12).padding(.vertical, 16)
                    }
                    if !bottomVisible && !lines.isEmpty {
                        Button {
                            withAnimation(.easeOut(duration: 0.25)) { reader.scrollTo("bottom", anchor: .bottom) }
                        } label: {
                            Image(systemName: "arrow.down")
                                .font(.headline.weight(.semibold))
                                .frame(width: 46, height: 46)
                                .background(.ultraThinMaterial, in: Circle())
                                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Jump to latest message")
                        .padding(14)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .refreshable { await reload() }
                .onChange(of: lines) { _, _ in withAnimation(.easeOut(duration: 0.22)) { reader.scrollTo("bottom", anchor: .bottom) } }
                .task { await reload(); try? await Task.sleep(for: .milliseconds(120)); reader.scrollTo("bottom", anchor: .bottom) }
            }
            Divider(); composer
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.backward").frame(width: 38, height: 38).background(.ultraThinMaterial, in: Circle())
                }.buttonStyle(.plain)
            }
            ToolbarItem(placement: .principal) {
                HStack(spacing: 7) { ProfileAvatar(name: session.profile, avatar: profile?.avatar, size: 27); Text(session.title).font(.subheadline.weight(.semibold)).lineLimit(1) }
                    .padding(.horizontal, 12).frame(height: 38).background(.ultraThinMaterial, in: Capsule())
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { Task { await reload() } } label: { Label("Refresh", systemImage: "arrow.clockwise") }
                    Button { newConversation() } label: { Label("New conversation", systemImage: "plus.bubble") }
                    Button { input = "/fork"; send() } label: { Label("Fork conversation", systemImage: "arrow.triangle.branch") }
                } label: { Image(systemName: "ellipsis").frame(width: 38, height: 38).background(.ultraThinMaterial, in: Circle()) }
            }
        }
        .confirmationDialog("Message actions", isPresented: Binding(get: { actionLine != nil }, set: { if !$0 { actionLine = nil } }), presenting: actionLine) { line in
            Button("Copy") { UIPasteboard.general.string = line.text; actionLine = nil }
            Button("Reply") { replyingTo = line; inputFocused = true; actionLine = nil }
            Button("Fork conversation") { actionLine = nil; input = "/fork"; send() }
            Button("Cancel", role: .cancel) { actionLine = nil }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in if case let .success(urls) = result { Task { await upload(urls) } } }
        .task { await loadModels() }
        .onChange(of: scenePhase) { _, phase in
            // Studio keeps running after the app is backgrounded. Pull the
            // persisted history as soon as the conversation becomes visible.
            if phase == .active { Task { await reload() } }
        }
        .onDisappear { socket.close(); if recorder.isRecording { _ = recorder.stop() } }
    }

    private var profile: Profile? { store.profiles.first { $0.name == session.profile } }

    private var composerIsEmpty: Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        attachments.isEmpty && !recorder.isRecording && !uploading
    }

    private var composer: some View {
        Group {
            if !composerExpanded && composerIsEmpty {
                HStack {
                    Button {
                        composerExpanded = true
                        inputFocused = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3.weight(.medium))
                            .frame(width: 48, height: 48)
                            .background(.ultraThinMaterial, in: Circle())
                            .shadow(color: .black.opacity(0.16), radius: 5, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open message composer")
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.top, 7)
            } else {
                expandedComposer
            }
        }
        .padding(.bottom, 6)
        .onChange(of: inputFocused) { _, focused in
            if !focused && composerIsEmpty { composerExpanded = false }
        }
    }

    private var expandedComposer: some View {
        VStack(spacing: 9) {
            if let replyingTo {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) { Text("Replying to").font(.caption.weight(.semibold)).foregroundStyle(HermesTheme.purple); Text(replyingTo.text).font(.caption).lineLimit(2) }
                    Spacer(); Button { self.replyingTo = nil } label: { Image(systemName: "xmark.circle.fill") }
                }.padding(10).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14)).padding(.horizontal, 10)
            }
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(attachments) { item in HStack(spacing: 6) { Image(systemName: item.mime.hasPrefix("image/") ? "photo" : "doc"); Text(item.name).lineLimit(1); Button { attachments.removeAll { $0.id == item.id } } label: { Image(systemName: "xmark.circle.fill") } }.font(.caption).padding(8).background(.thinMaterial, in: Capsule()) } }.padding(.horizontal, 12) }
            }
            if recorder.isRecording { HStack { Circle().fill(.red).frame(width: 8, height: 8); Text("Recording \(recorder.elapsed.formatted(.number.precision(.fractionLength(0))))s").font(.caption.monospacedDigit()); Spacer(); Text("Tap the microphone to transcribe").font(.caption2).foregroundStyle(.secondary) }.padding(.horizontal, 16) }
            TextField("Type a message…", text: $input, axis: .vertical)
                .lineLimit(1...6)
                .focused($inputFocused)
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                .onSubmit { if !input.isEmpty { send() } }
                .padding(.horizontal, 10)
            HStack(alignment: .center, spacing: 9) {
                Menu {
                    Button { importing = true } label: { Label("Attach files", systemImage: "paperclip") }
                    Button { newConversation() } label: { Label("New conversation", systemImage: "plus.bubble") }
                } label: { Image(systemName: uploading ? "hourglass" : "plus").font(.title3.weight(.medium)).frame(width: 42, height: 42).background(Color(uiColor: .secondarySystemBackground), in: Circle()) }.disabled(uploading)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        Label(session.profile, systemImage: "person.crop.circle")
                        Menu { Button("Default") { store.setReasoning("") }; ForEach(["low", "medium", "high", "xhigh"], id: \.self) { value in Button(value.capitalized) { store.setReasoning(value) } } } label: { Label(store.reasoningEffort.nilIfEmpty?.capitalized ?? String(localized: "Default"), systemImage: "brain.head.profile") }
                        Menu {
                            ForEach(models) { model in
                                Button(model.name) {
                                    selectedModel = model.id
                                    selectedProvider = model.provider
                                    Task { await refreshContextWindow() }
                                }
                            }
                        } label: { Label(selectedModel.nilIfEmpty ?? session.model.nilIfEmpty ?? String(localized: "Model"), systemImage: "cpu") }
                        if speechPlayer.isPlaying { Button { speechPlayer.stop() } label: { Label("Stop voice", systemImage: "stop.fill") } }
                        ContextUsageView(tokens: contextTokens, window: contextWindow, loading: loadingContext)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && attachments.isEmpty {
                    Button { Task { await voice() } } label: { Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill").font(.title3).foregroundStyle(recorder.isRecording ? .red : .primary).frame(width: 44, height: 44).background(Color(uiColor: .secondarySystemBackground), in: Circle()) }
                } else {
                    Button(action: send) { Image(systemName: sending ? "stop.fill" : "arrow.up").font(.headline).foregroundStyle(.white).frame(width: 44, height: 44).background((sending ? Color.red : HermesTheme.purple).gradient, in: Circle()) }
                }
            }.padding(.horizontal, 10)
        }
        .padding(.top, 9)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
        .padding(.horizontal, 8)
    }

    private func reload() async {
        loading = true
        do {
            let history = try await store.api.conversationHistory(sessionID: session.id)
            lines = history.messages.map { ChatLine(text: $0.content, fromUser: $0.role == "user", timestamp: $0.sentAt, sender: $0.role == "user" ? nil : session.profile) }
            contextTokens = history.contextTokens ?? contextTokens
        }
        catch { if lines.isEmpty && session.title != String(localized: "New conversation") { store.errorMessage = error.localizedDescription } }
        loading = false
    }

    private func loadModels() async {
        models = (try? await store.api.models(profile: session.profile)) ?? []
        selectedModel = session.model.nilIfEmpty ?? profile?.model ?? models.first?.id ?? ""
        selectedProvider = models.first { $0.id == selectedModel }?.provider ?? session.provider
        await refreshContextWindow()
    }

    private func refreshContextWindow() async {
        loadingContext = true
        contextWindow = (try? await store.api.contextLength(profile: session.profile, provider: selectedProvider, model: selectedModel)) ?? contextWindow
        loadingContext = false
    }

    private func send() {
        if sending { socket.abort(sessionID: session.id); socket.close(); sending = false; if let index = lines.indices.last { lines[index].isStreaming = false; lines[index].finishedAt = .now }; return }
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines); guard !text.isEmpty || !attachments.isEmpty else { return }
        if let replyingTo {
            let quote = replyingTo.text.split(separator: "\n", omittingEmptySubsequences: false).prefix(8).map { "> \($0)" }.joined(separator: "\n")
            text = [quote, text].filter { !$0.isEmpty }.joined(separator: "\n\n")
            self.replyingTo = nil
        }
        let wantsVoiceReply = voiceReplyPending; voiceReplyPending = false
        let files = attachments; input = ""; attachments = []; inputFocused = false
        lines.append(ChatLine(text: text.isEmpty ? files.map(\.name).joined(separator: ", ") : text, fromUser: true))
        lines.append(ChatLine(text: "", fromUser: false, sender: session.profile, isStreaming: true))
        let replyID = lines.last!.id; sending = true
        Task {
            var gotAnything = false
            let stream = socket.run(baseURL: store.baseURL, token: store.token, profile: session.profile, sessionID: session.id, input: text, attachments: files, reasoningEffort: store.reasoningEffort.nilIfEmpty, model: selectedModel.nilIfEmpty, provider: selectedProvider.nilIfEmpty)
            for await event in stream {
                guard let index = lines.firstIndex(where: { $0.id == replyID }) else { continue }
                switch event {
                case let .started(date): lines[index].startedAt = date; gotAnything = true
                case let .text(delta): lines[index].text += delta; gotAnything = true
                case let .reasoning(delta): lines[index].reasoning += delta; gotAnything = true
                case let .tool(id, name, detail, status, duration): updateTool(index: index, id: id, name: name, detail: detail, status: status, duration: duration); gotAnything = true
                case let .usage(tokens, window): contextTokens = tokens; if let window { contextWindow = window }
                case let .completed(output, reasoning): if lines[index].text.isEmpty { lines[index].text = output }; if lines[index].reasoning.isEmpty { lines[index].reasoning = reasoning }; lines[index].isStreaming = false; lines[index].finishedAt = .now
                case let .requiresAction(kind): lines[index].text += kind.contains("approval") ? String(localized: "This run needs approval in Studio.") : String(localized: "This run needs clarification in Studio."); lines[index].isStreaming = false
                case let .failed(message, retryable):
                    if retryable && !gotAnything { await restFallback(index: index, text: text, files: files) }
                    else { lines[index].text = lines[index].text.nilIfEmpty ?? message; lines[index].isError = true; lines[index].isStreaming = false }
                }
            }
            if let index = lines.firstIndex(where: { $0.id == replyID }) { lines[index].isStreaming = false; lines[index].finishedAt = .now }
            if wantsVoiceReply, let reply = lines.first(where: { $0.id == replyID })?.text.nilIfEmpty {
                await speak(reply)
            }
            sending = false; Preferences.setSession(session.id, profile: session.profile)
        }
    }

    private func restFallback(index: Int, text: String, files: [Upload]) async {
        do { let result = try await store.api.runChatREST(profile: session.profile, sessionID: session.id, input: text, attachments: files, reasoningEffort: store.reasoningEffort.nilIfEmpty, model: selectedModel.nilIfEmpty, provider: selectedProvider.nilIfEmpty); lines[index].text = result.0; lines[index].reasoning = result.1 }
        catch { lines[index].text = error.localizedDescription; lines[index].isError = true }
    }

    private func updateTool(index: Int, id: String, name: String, detail: String?, status: ToolStatus, duration: Double?) {
        if let toolIndex = lines[index].tools.firstIndex(where: { $0.id == id }) { lines[index].tools[toolIndex].status = status; lines[index].tools[toolIndex].detail = detail ?? lines[index].tools[toolIndex].detail; lines[index].tools[toolIndex].duration = duration }
        else { lines[index].tools.append(ToolStep(id: id, name: name, detail: detail, status: status, duration: duration, startedAt: .now)) }
    }

    private func upload(_ urls: [URL]) async {
        uploading = true; defer { uploading = false }
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do { let data = try Data(contentsOf: url); let type = (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)?.preferredMIMEType ?? "application/octet-stream"; attachments.append(try await store.api.upload(data: data, name: url.lastPathComponent, mime: type, profile: session.profile)) }
            catch { store.errorMessage = error.localizedDescription }
        }
    }

    private func voice() async {
        if recorder.isRecording {
            guard let url = recorder.stop() else { return }; uploading = true; defer { uploading = false }
            do { input = try await store.api.transcribe(data: Data(contentsOf: url), name: url.lastPathComponent, mime: "audio/mp4", profile: session.profile); voiceReplyPending = true; inputFocused = true }
            catch { store.errorMessage = error.localizedDescription }
        } else { _ = await recorder.toggle() }
    }
    private func newConversation() { input = ""; attachments = []; lines = [] }

    private func speak(_ text: String) async {
        do { try speechPlayer.play(await store.api.synthesize(text: text, profile: session.profile)) }
        catch { store.errorMessage = error.localizedDescription }
    }
}

private struct ContextUsageView: View {
    let tokens: Int
    let window: Int
    let loading: Bool

    private var ratio: Double { window > 0 ? min(1, max(0, Double(tokens) / Double(window))) : 0 }
    private var color: Color { ratio > 0.8 ? .red : ratio > 0.6 ? .orange : .secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(loading ? String(localized: "Context…") : window > 0 ? "\(String(localized: "Context")) \(compact(tokens)) / \(compact(window))" : String(localized: "Context —"))
                .font(.caption2)
                .lineLimit(1)
            ProgressView(value: ratio)
                .tint(color)
                .frame(width: 88)
        }
        .foregroundStyle(color)
    }

    private func compact(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000).replacingOccurrences(of: ".0", with: "") }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000).replacingOccurrences(of: ".0", with: "") }
        return String(value)
    }
}

private struct MessageBubble: View {
    let line: ChatLine
    let profile: Profile?
    let api: APIClient
    let sessionProfile: String
    let onTap: () -> Void
    @State private var reasoningExpanded = true
    var body: some View {
        let parsed = ChatFiles.parse(line.text)
        HStack(alignment: .bottom, spacing: 8) {
            if line.fromUser { Spacer(minLength: 45) } else { ProfileAvatar(name: sessionProfile, avatar: profile?.avatar, size: 30) }
            VStack(alignment: .leading, spacing: 9) {
                if !line.reasoning.isEmpty || !line.tools.isEmpty || line.isStreaming {
                    DisclosureGroup(isExpanded: $reasoningExpanded) {
                        VStack(alignment: .leading, spacing: 7) {
                            if !line.reasoning.isEmpty { Text(line.reasoning).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
                            ForEach(line.tools) { tool in ToolStepRow(tool: tool) }
                        }.padding(.top, 7)
                    } label: {
                        HStack { Image(systemName: line.isStreaming ? "brain.filled.head.profile" : "brain.head.profile"); Text(line.isStreaming ? "Thinking" : "Thinking details").fontWeight(.semibold); if line.isStreaming { ProgressView().controlSize(.mini) } }
                    }.font(.subheadline)
                }
                if !parsed.text.isEmpty { MarkdownText(text: parsed.text).font(.body).foregroundStyle(line.isError ? .red : .primary) }
                ForEach(parsed.files) { link in FileDownloadCard(link: link, url: api.downloadURL(path: link.path, name: ChatFiles.fileName(for: link), profile: sessionProfile)) }
                HStack(spacing: 5) { if line.isStreaming { ProgressView().controlSize(.mini) }; if let timestamp = line.timestamp { Text(timestamp.chatTime) } }.font(.caption2).foregroundStyle(.secondary)
            }
            // Assistant replies need a real proposed width so an RTL paragraph
            // can align against the bubble's right edge. User bubbles remain
            // compact and grow only as much as their own content needs.
            .frame(maxWidth: line.fromUser ? nil : .infinity, alignment: .leading)
            .padding(13)
            .background(line.fromUser ? HermesTheme.purple.opacity(0.17) : Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 21, style: .continuous))
            .frame(maxWidth: line.fromUser ? 560 : .infinity, alignment: .leading)
            if !line.fromUser { Spacer(minLength: 24) }
        }.frame(maxWidth: .infinity).contentShape(Rectangle()).onTapGesture(perform: onTap)
    }
}

private struct ToolStepRow: View {
    let tool: ToolStep
    var body: some View {
        HStack(spacing: 9) { ToolIcon(name: tool.name); VStack(alignment: .leading, spacing: 2) { Text(tool.name).font(.caption.weight(.semibold)).lineLimit(1); if let detail = tool.detail { Text(detail).font(.caption2.monospaced()).foregroundStyle(.secondary).lineLimit(2) } }; Spacer(); if let duration = tool.duration { Text("\(duration, specifier: "%.1f")s").font(.caption2.monospacedDigit()).foregroundStyle(.secondary) }; Group { switch tool.status { case .running: ProgressView(); case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green); case .error: Image(systemName: "xmark.circle.fill").foregroundStyle(.red) } }.controlSize(.small) }
            .padding(7).background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    }
}
