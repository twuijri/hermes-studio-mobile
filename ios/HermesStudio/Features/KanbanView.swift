import SwiftUI

struct KanbanView: View {
    @EnvironmentObject private var store: AppStore
    @State private var boards: [KanbanBoard] = []
    @State private var selectedBoard = "default"
    @State private var tasks: [KanbanTask] = []
    @State private var loading = true
    @State private var creating = false
    @State private var selectedTask: KanbanTask?

    var body: some View {
        VStack(spacing: 0) {
            if boards.count > 1 { boardPicker }
            boardContent
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Kanban")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { Task { await loadTasks() } } label: { Image(systemName: "arrow.clockwise") }
                Button { creating = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $creating) { TaskEditorView(board: selectedBoard) { await loadTasks() } }
        .sheet(item: $selectedTask) { task in TaskDetailView(task: task, board: selectedBoard) { await loadTasks() } }
        .task { await load() }
        .onChange(of: selectedBoard) { _, _ in Task { await loadTasks() } }
    }

    private var boardPicker: some View {
        Picker("Board", selection: $selectedBoard) {
            ForEach(boards) { board in Text(board.name).tag(board.id) }
        }.pickerStyle(.segmented).padding()
    }

    @ViewBuilder private var boardContent: some View {
        if loading && tasks.isEmpty {
            Spacer(); ProgressView("Loading board…"); Spacer()
        } else {
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(KanbanStatus.allCases) { status in column(status) }
                }.padding(14)
            }
        }
    }

    private func column(_ status: KanbanStatus) -> some View {
        let visibleTasks = tasks.filter { normalized($0.status) == status.rawValue }
        return KanbanColumn(status: status, tasks: visibleTasks, onOpen: { selectedTask = $0 })
            .dropDestination(for: String.self) { ids, _ in
                Task { await move(ids: ids, to: status) }
                return true
            }
    }
    private func normalized(_ status: String) -> String { status.lowercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_") == "inprogress" ? "in_progress" : status.lowercased().replacingOccurrences(of: "-", with: "_").replacingOccurrences(of: " ", with: "_") }
    private func load() async { loading = true; do { boards = try await store.api.boards(); if !boards.contains(where: { $0.id == selectedBoard }) { selectedBoard = boards.first?.id ?? "default" }; await loadTasks() } catch { store.errorMessage = error.localizedDescription }; loading = false }
    private func loadTasks() async { do { tasks = try await store.api.kanbanTasks(board: selectedBoard) } catch { store.errorMessage = error.localizedDescription } }
    private func move(ids: [String], to status: KanbanStatus) async { let old = tasks; for index in tasks.indices where ids.contains(tasks[index].id) { tasks[index].status = status.rawValue }; do { try await store.api.moveTasks(board: selectedBoard, ids: ids, status: status.rawValue) } catch { tasks = old; store.errorMessage = error.localizedDescription } }
}

private struct KanbanColumn: View {
    let status: KanbanStatus
    let tasks: [KanbanTask]
    let onOpen: (KanbanTask) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack { Circle().fill(color).frame(width: 9, height: 9); Text(status.title).font(.headline); Spacer(); Text("\(tasks.count)").font(.caption.bold()).foregroundStyle(.secondary).padding(.horizontal, 8).padding(.vertical, 4).background(.primary.opacity(0.06), in: Capsule()) }
            ForEach(tasks) { task in Button { onOpen(task) } label: { KanbanCard(task: task) }.buttonStyle(.plain).draggable(task.id) }
            if tasks.isEmpty { VStack(spacing: 8) { Image(systemName: "rectangle.dashed"); Text("Drop tasks here").font(.caption) }.foregroundStyle(.tertiary).frame(maxWidth: .infinity).frame(height: 90) }
        }.padding(13).frame(width: 292).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20)).overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.16)))
    }
    private var color: Color {
        switch status {
        case .triage: .gray
        case .todo: .blue
        case .scheduled: .purple
        case .ready: .teal
        case .running: .orange
        case .blocked: .red
        case .review: .indigo
        case .done: .green
        }
    }
}

private struct KanbanCard: View {
    let task: KanbanTask
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top) { Text(task.title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.leading); Spacer(); Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary) }
            if !task.description.isEmpty { Text(task.description).font(.caption).foregroundStyle(.secondary).lineLimit(3).multilineTextAlignment(.leading) }
            FlowLayout(spacing: 5) { ForEach(task.tags, id: \.self) { Text($0).font(.caption2).padding(.horizontal, 7).padding(.vertical, 3).background(HermesTheme.purple.opacity(0.1), in: Capsule()) } }
            HStack { StatusPill(text: task.priority.capitalized, color: task.priority.lowercased() == "high" ? .red : .blue); Spacer(); if let assignee = task.assignee { Label(assignee, systemImage: "person.crop.circle").font(.caption2).foregroundStyle(.secondary) } }
        }.padding(13).background(Color(uiColor: .systemBackground), in: RoundedRectangle(cornerRadius: 15)).shadow(color: .black.opacity(0.05), radius: 8, y: 3)
    }
}

private struct TaskEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let board: String
    let onSave: () async -> Void
    @State private var title = ""; @State private var description = ""; @State private var priority = "medium"; @State private var saving = false
    var body: some View {
        NavigationStack { Form { Section("Task") { TextField("Title", text: $title); TextField("Description", text: $description, axis: .vertical).lineLimit(3...8) }; Section("Priority") { Picker("Priority", selection: $priority) { Text("Low").tag("low"); Text("Medium").tag("medium"); Text("High").tag("high") }.pickerStyle(.segmented) } }.navigationTitle("New task").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button("Create") { Task { await save() } }.disabled(title.isEmpty || saving) } } }
    }
    private func save() async { saving = true; do { try await store.api.createTask(board: board, title: title, description: description, priority: priority); await onSave(); dismiss() } catch { store.errorMessage = error.localizedDescription }; saving = false }
}

private struct TaskDetailView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let task: KanbanTask; let board: String; let onChange: () async -> Void
    @State private var comment = ""; @State private var assignee = ""
    var body: some View {
        NavigationStack { Form { Section { Text(task.title).font(.title3.bold()); if !task.description.isEmpty { Text(task.description) } } header: { Text("Task") }; Section("Status") { Picker("Status", selection: Binding(get: { task.status }, set: { value in Task { try? await store.api.moveTasks(board: board, ids: [task.id], status: value); await onChange(); dismiss() } })) { ForEach(KanbanStatus.allCases) { Text($0.title).tag($0.rawValue) } } }; Section("Assignee") { Picker("Agent", selection: $assignee) { Text("Unassigned").tag(""); ForEach(store.profiles) { Text($0.name).tag($0.name) } }.onChange(of: assignee) { _, value in Task { try? await store.api.assignTask(board: board, id: task.id, profile: value.nilIfEmpty); await onChange() } } }; Section("Comment") { TextField("Add a comment…", text: $comment, axis: .vertical); Button("Post comment") { Task { try? await store.api.commentTask(board: board, id: task.id, comment: comment); comment = ""; await onChange() } }.disabled(comment.isEmpty) } }.navigationTitle("Task details").navigationBarTitleDisplayMode(.inline).toolbar { Button("Done") { dismiss() } }.onAppear { assignee = task.assignee ?? "" } }
    }
}
