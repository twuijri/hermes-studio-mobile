import SwiftUI

struct GroupsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var rooms: [Room] = []
    @State private var loading = true
    @State private var creating = false

    var body: some View {
        Group {
            if loading && rooms.isEmpty { ProgressView("Loading groups…") }
            else if rooms.isEmpty { EmptyState(icon: "person.3", title: "No groups", detail: "Create a room where people and agents work together.") }
            else {
                List(rooms) { room in
                    NavigationLink { GroupRoomView(room: room) } label: {
                        HStack(spacing: 13) {
                            ZStack { RoundedRectangle(cornerRadius: 15).fill(LinearGradient(colors: [HermesTheme.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)); Image(systemName: "person.3.fill").foregroundStyle(.white) }.frame(width: 50, height: 50)
                            VStack(alignment: .leading, spacing: 5) { Text(room.name).font(.headline); HStack { Label("\(room.agentCount) agents", systemImage: "sparkles"); Label("\(room.memberCount) members", systemImage: "person.2") }.font(.caption).foregroundStyle(.secondary) }
                        }.padding(.vertical, 4)
                    }.swipeActions { Button(role: .destructive) { Task { await delete(room) } } label: { Label("Delete", systemImage: "trash") } }
                }.listStyle(.insetGrouped).refreshable { await load() }
            }
        }
        .navigationTitle("Groups")
        .toolbar { ToolbarItemGroup(placement: .topBarTrailing) { Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }; Button { creating = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $creating) { CreateGroupView { room in rooms.insert(room, at: 0) } }
        .task { await load() }
    }
    private func load() async { loading = true; do { rooms = try await store.api.rooms() } catch { store.errorMessage = error.localizedDescription }; loading = false }
    private func delete(_ room: Room) async { do { try await store.api.deleteRoom(room.id); rooms.removeAll { $0.id == room.id } } catch { store.errorMessage = error.localizedDescription } }
}

private struct CreateGroupView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var inviteCode = ""
    @State private var selected: Set<String> = []
    @State private var saving = false
    let onCreated: (Room) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Group") { TextField("Name", text: $name); TextField("Invite code", text: $inviteCode).textInputAutocapitalization(.never) }
                Section("Agents") { ForEach(store.profiles) { profile in Button { if selected.contains(profile.name) { selected.remove(profile.name) } else { selected.insert(profile.name) } } label: { HStack { ProfileAvatar(name: profile.name, avatar: profile.avatar, size: 36); Text(profile.name).foregroundStyle(.primary); Spacer(); if selected.contains(profile.name) { Image(systemName: "checkmark.circle.fill").foregroundStyle(HermesTheme.purple) } } } } }
            }
            .navigationTitle("New group").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(saving ? "Creating…" : "Create") { Task { await save() } }.disabled(name.isEmpty || inviteCode.isEmpty || saving) } }
        }
    }
    private func save() async { saving = true; do { let room = try await store.api.createRoom(name: name, inviteCode: inviteCode, agents: Array(selected)); onCreated(room); dismiss() } catch { store.errorMessage = error.localizedDescription }; saving = false }
}

struct GroupRoomView: View {
    @EnvironmentObject private var store: AppStore
    let room: Room
    @State private var messages: [RoomMessage] = []
    @State private var input = ""
    @State private var socket = GroupSocket()
    @State private var connectionTask: Task<Void, Never>?
    @State private var connected = false
    @State private var addingAgent = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { reader in
                ScrollView {
                    LazyVStack(spacing: 12) { ForEach(messages) { message in roomBubble(message) }; Color.clear.frame(height: 1).id("bottom") }.padding(12)
                }.refreshable { await history() }.onChange(of: messages) { _, _ in withAnimation { reader.scrollTo("bottom", anchor: .bottom) } }.task { await history(); reader.scrollTo("bottom", anchor: .bottom); connect() }
            }
            Divider()
            HStack(alignment: .bottom, spacing: 9) {
                TextField("Message the group…", text: $input, axis: .vertical).lineLimit(1...5).padding(.horizontal, 15).padding(.vertical, 11).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 20))
                Button { send() } label: { Image(systemName: "arrow.up").font(.headline).foregroundStyle(.white).frame(width: 44, height: 44).background((input.isEmpty || !connected ? Color.gray : HermesTheme.purple).gradient, in: Circle()) }.disabled(input.isEmpty || !connected)
            }.padding(10).background(.ultraThinMaterial)
        }
        .navigationTitle(room.name).navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { StatusPill(text: connected ? String(localized: "Live") : String(localized: "Offline"), color: connected ? .green : .orange) }
            ToolbarItem(placement: .topBarTrailing) { Button { addingAgent = true } label: { Image(systemName: "person.badge.plus") } }
        }
        .sheet(isPresented: $addingAgent) { AddRoomAgentView(roomID: room.id) }
        .onDisappear { connectionTask?.cancel(); socket.close() }
    }

    private func history() async { do { messages = try await store.api.room(room.id).1 } catch { store.errorMessage = error.localizedDescription } }
    private func connect() {
        connectionTask?.cancel()
        connectionTask = Task {
            for await event in socket.join(baseURL: store.baseURL, token: store.token, roomID: room.id, memberName: store.currentUser?.username ?? "iPhone") {
                switch event { case .connected: connected = true; case let .message(message): if !messages.contains(where: { $0.id == message.id }) { messages.append(message) }; case .disconnected: connected = false; case let .failed(error): connected = false; store.errorMessage = error }
            }
        }
    }
    private func send() { let text = input.trimmingCharacters(in: .whitespacesAndNewlines); guard !text.isEmpty else { return }; if socket.post(text, senderName: store.currentUser?.username ?? "iPhone") { input = "" } }
    private func roomBubble(_ message: RoomMessage) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if !message.isAgent { Spacer(minLength: 42) }
            if message.isAgent { ProfileAvatar(name: message.sender, avatar: store.profiles.first { $0.name == message.sender }?.avatar, size: 29) }
            VStack(alignment: .leading, spacing: 5) { if message.isAgent { Text(message.sender).font(.caption.weight(.semibold)).foregroundStyle(HermesTheme.purple) }; MarkdownText(text: message.content); if let timestamp = message.timestamp { Text(timestamp.relativeDate).font(.caption2).foregroundStyle(.secondary) } }.padding(12).background(message.isAgent ? Color(uiColor: .secondarySystemBackground) : HermesTheme.purple.opacity(0.17), in: RoundedRectangle(cornerRadius: 19)).frame(maxWidth: 550, alignment: .leading)
            if message.isAgent { Spacer(minLength: 28) }
        }.frame(maxWidth: .infinity)
    }
}

private struct AddRoomAgentView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let roomID: String
    var body: some View {
        NavigationStack { List(store.profiles) { profile in Button { Task { do { try await store.api.addRoomAgent(roomID, profile: profile.name); store.notify(String(localized: "Agent added")); dismiss() } catch { store.errorMessage = error.localizedDescription } } } label: { HStack { ProfileAvatar(name: profile.name, avatar: profile.avatar); Text(profile.name).foregroundStyle(.primary); Spacer(); Image(systemName: "plus.circle.fill") } } }.navigationTitle("Add agent").toolbar { Button("Done") { dismiss() } } }
    }
}
