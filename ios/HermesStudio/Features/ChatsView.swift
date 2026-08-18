import SwiftUI

struct ChatsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var sessions: [SessionSummary] = []
    @State private var search = ""
    @State private var profileFilter = ""
    @State private var loading = true
    @State private var editSession: SessionSummary?
    @State private var newTitle = ""

    var body: some View {
        Group {
            if loading && sessions.isEmpty { ProgressView("Loading conversations…") }
            else {
                List {
                    Section {
                        HStack(spacing: 10) {
                            Menu {
                                Button { profileFilter = "" } label: {
                                    if profileFilter.isEmpty { Label("All profiles", systemImage: "checkmark") }
                                    else { Text("All profiles") }
                                }
                                Divider()
                                ForEach(store.profiles) { profile in
                                    Button { profileFilter = profile.name } label: {
                                        if profileFilter == profile.name { Label(profile.name, systemImage: "checkmark") }
                                        else { Text(profile.name) }
                                    }
                                }
                            } label: {
                                Label(profileFilter.isEmpty ? String(localized: "All profiles") : profileFilter, systemImage: "line.3.horizontal.decrease.circle")
                                    .font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                            Text("\(sessions.count) \(String(localized: "conversations"))").font(.caption).foregroundStyle(.secondary)
                        }
                        SearchBar(text: $search).listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                    if filtered.isEmpty {
                        EmptyState(icon: "bubble.left.and.bubble.right", title: "No conversations", detail: "Start a conversation with your Hermes agent.")
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    }
                    ForEach(filtered) { session in
                        NavigationLink { ConversationView(session: session) } label: { SessionRow(session: session, profile: store.profiles.first { $0.name == session.profile } ?? store.profile) }
                            .swipeActions(edge: .trailing) { Button(role: .destructive) { Task { await delete(session) } } label: { Label("Delete", systemImage: "trash") }; Button { newTitle = session.title; editSession = session } label: { Label("Rename", systemImage: "pencil") }.tint(.blue) }
                    }
                }.listStyle(.insetGrouped).refreshable { await load() }
            }
        }
        .navigationTitle("Chats")
        .toolbar {
            if #available(iOS 26.0, *) {
                ToolbarItem(placement: .topBarLeading) { ProfileMenu() }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: .topBarLeading) { ProfileMenu() }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("Refresh")
                NavigationLink { ConversationView(session: newSession) } label: { Image(systemName: "square.and.pencil") }.accessibilityLabel("New conversation")
            }
        }
        .task(id: profileFilter) { await load() }
        .alert("Rename conversation", isPresented: Binding(get: { editSession != nil }, set: { if !$0 { editSession = nil } })) {
            TextField("Title", text: $newTitle)
            Button("Save") { guard let editSession else { return }; Task { try? await store.api.renameSession(editSession.id, title: newTitle); await load() } }
            Button("Cancel", role: .cancel) { editSession = nil }
        }
    }

    private var filtered: [SessionSummary] { search.isEmpty ? sessions : sessions.filter { $0.title.localizedCaseInsensitiveContains(search) || $0.model.localizedCaseInsensitiveContains(search) } }
    private var newSession: SessionSummary { SessionSummary(["id": UUID().uuidString, "title": String(localized: "New conversation"), "profile": store.selectedProfile], profile: store.selectedProfile) }
    private func load() async { loading = true; do { sessions = try await store.api.sessions(profile: profileFilter.nilIfEmpty) } catch { store.errorMessage = error.localizedDescription }; loading = false }
    private func delete(_ session: SessionSummary) async { do { try await store.api.deleteSession(session.id); sessions.removeAll { $0.id == session.id } } catch { store.errorMessage = error.localizedDescription } }
}

private struct SessionRow: View {
    let session: SessionSummary
    let profile: Profile?
    var body: some View {
        HStack(spacing: 13) {
            ProfileAvatar(name: session.profile, avatar: profile?.avatar, size: 48)
            VStack(alignment: .leading, spacing: 5) {
                Text(session.title).font(.headline).lineLimit(2)
                HStack(spacing: 5) { Text(session.profile); if !session.model.isEmpty { Text("·"); Text(session.model) } }.font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 5); if !session.updatedAt.isEmpty { Text(session.updatedAt.relativeDate).font(.caption2).foregroundStyle(.tertiary) }
        }.padding(.vertical, 4)
    }
}

struct ProfileMenu: View {
    @EnvironmentObject private var store: AppStore
    @State private var isChoosingProfile = false
    @State private var isManagingProfiles = false

    var body: some View {
        ProfileAvatar(name: store.selectedProfile, avatar: store.profile?.avatar, size: 34)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onTapGesture { isChoosingProfile = true }
            .accessibilityLabel("Profiles")
            .accessibilityAddTraits(.isButton)
            .confirmationDialog("Choose profile", isPresented: $isChoosingProfile, titleVisibility: .visible) {
                ForEach(store.profiles) { profile in
                    Button {
                        store.chooseProfile(profile.name)
                    } label: {
                        if profile.name == store.selectedProfile {
                            Label(profile.name, systemImage: "checkmark")
                        } else {
                            Text(profile.name)
                        }
                    }
                }
                Button("Manage profiles") { isManagingProfiles = true }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $isManagingProfiles) {
                NavigationStack {
                    ProfilesView()
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { isManagingProfiles = false }
                            }
                        }
                }
                .environmentObject(store)
            }
    }
}
