import SwiftUI

struct CronJobsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var jobs: [CronJob] = []
    @State private var loading = true
    @State private var editing: CronJob?
    @State private var creating = false

    var body: some View {
        Group {
            if loading && jobs.isEmpty { ProgressView("Loading jobs…") }
            else if jobs.isEmpty { EmptyState(icon: "calendar.badge.clock", title: "No scheduled jobs", detail: "Automate an agent prompt on a schedule.") }
            else {
                List {
                    ForEach(jobs) { job in
                        Button { editing = job } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack { VStack(alignment: .leading, spacing: 3) { Text(job.name).font(.headline).foregroundStyle(.primary); Text(job.schedule).font(.caption.monospaced()).foregroundStyle(.secondary) }; Spacer(); StatusPill(text: job.enabled ? String(localized: "Scheduled") : String(localized: "Paused"), color: job.enabled ? .green : .orange) }
                                if !job.prompt.isEmpty { Text(job.prompt).font(.subheadline).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading) }
                                HStack { if let next = job.nextRun { Label(next.relativeDate, systemImage: "clock") }; Spacer(); Button { Task { await run(job) } } label: { Label("Run now", systemImage: "play.fill") }.buttonStyle(.bordered).controlSize(.small); Button { Task { await toggle(job) } } label: { Image(systemName: job.enabled ? "pause.fill" : "play.fill") }.buttonStyle(.bordered).controlSize(.small) }.font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 6)
                        }.buttonStyle(.plain).swipeActions { Button(role: .destructive) { Task { await delete(job) } } label: { Label("Delete", systemImage: "trash") } }
                    }
                }.listStyle(.insetGrouped).refreshable { await load() }
            }
        }
        .navigationTitle("Scheduled Jobs")
        .toolbar { ToolbarItemGroup(placement: .topBarTrailing) { Button { Task { await load() } } label: { Image(systemName: "arrow.clockwise") }; Button { creating = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $creating) { CronEditorView(job: nil) { await load() } }
        .sheet(item: $editing) { job in CronEditorView(job: job) { await load() } }
        .task(id: store.selectedProfile) { await load() }
    }
    private func load() async { loading = true; do { jobs = try await store.api.cronJobs(profile: store.selectedProfile) } catch { store.errorMessage = error.localizedDescription }; loading = false }
    private func toggle(_ job: CronJob) async { do { try await store.api.setCronEnabled(job.id, enabled: !job.enabled, profile: store.selectedProfile); await load() } catch { store.errorMessage = error.localizedDescription } }
    private func run(_ job: CronJob) async { do { try await store.api.runCron(job.id, profile: store.selectedProfile); store.notify(String(localized: "Job started")); await load() } catch { store.errorMessage = error.localizedDescription } }
    private func delete(_ job: CronJob) async { do { try await store.api.deleteCron(job.id, profile: store.selectedProfile); jobs.removeAll { $0.id == job.id } } catch { store.errorMessage = error.localizedDescription } }
}

private struct CronEditorView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let job: CronJob?
    let onSave: () async -> Void
    @State private var name = ""; @State private var prompt = ""; @State private var schedule = "0 9 * * *"; @State private var preset = "daily"; @State private var enabled = true; @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Job") { TextField("Name", text: $name); TextField("What should the agent do?", text: $prompt, axis: .vertical).lineLimit(4...10) }
                Section("Schedule") {
                    Picker("Frequency", selection: $preset) { Text("Every hour").tag("hourly"); Text("Every day").tag("daily"); Text("Every week").tag("weekly"); Text("Custom cron").tag("custom") }.onChange(of: preset) { _, value in if value != "custom" { schedule = value == "hourly" ? "0 * * * *" : (value == "weekly" ? "0 9 * * 1" : "0 9 * * *") } }
                    TextField("Cron expression", text: $schedule).font(.body.monospaced()).textInputAutocapitalization(.never).disabled(preset != "custom")
                    Label(TimeZone.current.identifier, systemImage: "globe").foregroundStyle(.secondary)
                }
                Section { Toggle("Enabled", isOn: $enabled) } footer: { Text("Schedules run in your Studio, even while the iPhone app is closed.") }
            }.navigationTitle(job == nil ? "New job" : "Edit job").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(saving ? "Saving…" : "Save") { Task { await save() } }.disabled(name.isEmpty || prompt.isEmpty || schedule.isEmpty || saving) } }
                .onAppear { guard let job else { return }; name = job.name; prompt = job.prompt; schedule = job.schedule; enabled = job.enabled; preset = ["0 * * * *": "hourly", "0 9 * * *": "daily", "0 9 * * 1": "weekly"][schedule] ?? "custom" }
        }
    }
    private func save() async { saving = true; do { try await store.api.saveCron(id: job?.id, name: name, schedule: schedule, prompt: prompt, profile: store.selectedProfile, enabled: enabled); await onSave(); dismiss() } catch { store.errorMessage = error.localizedDescription }; saving = false }
}
