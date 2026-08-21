import SwiftUI

struct InsightsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var days = 30
    @State private var usage: UsageStats?
    @State private var runtime: RuntimePerformance?
    @State private var loading = true

    var body: some View {
        List {
            Section {
                Picker("Period", selection: $days) {
                    ForEach([7, 30, 90, 365], id: \.self) { Text("\($0) days").tag($0) }
                }.pickerStyle(.segmented)
            }
            if loading { Section { HStack { Spacer(); ProgressView(); Spacer() } } }
            if let usage {
                Section("Usage") {
                    metric("Tokens", compact(usage.inputTokens + usage.outputTokens), "number.square.fill", .purple)
                    metric("Sessions", "\(usage.sessions)", "bubble.left.and.bubble.right.fill", .blue)
                    metric("Estimated cost", usage.cost.formatted(.currency(code: "USD").precision(.fractionLength(4))), "dollarsign.circle.fill", .green)
                    metric("Cache tokens", compact(usage.cacheTokens), "bolt.horizontal.fill", .orange)
                }
                if !usage.models.isEmpty {
                    Section("By model") {
                        ForEach(usage.models.prefix(8)) { model in
                            LabeledContent { Text(compact(model.totalTokens)).fontWeight(.semibold) } label: {
                                VStack(alignment: .leading) { Text(model.name); Text("\(model.sessions) sessions").font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
            }
            if let runtime {
                Section("Studio runtime") {
                    metric("CPU", runtime.cpuPercent.map { String(format: "%.1f%%", $0) } ?? "—", "cpu", .mint)
                    metric("System memory", runtime.memoryPercent.map { String(format: "%.1f%%", $0) } ?? "—", "memorychip.fill", .pink)
                    metric("Bridge workers", "\(runtime.runningWorkers)/\(runtime.workerCount)", "point.3.connected.trianglepath.dotted", .cyan)
                    metric("Live sessions", "\(runtime.sessionCount)", "waveform.path.ecg", .indigo)
                }
            }
        }
        .navigationTitle("Insights")
        .refreshable { await load() }
        .task(id: days) { await load() }
    }

    private func metric(_ title: LocalizedStringKey, _ value: String, _ icon: String, _ color: Color) -> some View {
        HStack { Image(systemName: icon).foregroundStyle(color).frame(width: 24); Text(title); Spacer(); Text(value).fontWeight(.bold).foregroundStyle(HermesTheme.purple) }
    }

    private func compact(_ value: Int) -> String {
        if value >= 1_000_000 { return String(format: "%.1fM", Double(value) / 1_000_000) }
        if value >= 1_000 { return String(format: "%.1fK", Double(value) / 1_000) }
        return "\(value)"
    }

    private func load() async {
        loading = true
        do {
            async let usageRequest = store.api.usageStats(days: days)
            async let runtimeRequest = store.api.runtimePerformance()
            (usage, runtime) = try await (usageRequest, runtimeRequest)
        } catch { store.errorMessage = error.localizedDescription }
        loading = false
    }
}
