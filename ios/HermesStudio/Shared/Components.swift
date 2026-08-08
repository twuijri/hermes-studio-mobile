import SwiftUI
import QuickLook

struct EmptyState: View {
    let icon: String
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var body: some View {
        ContentUnavailableView { Label(title, systemImage: icon) } description: { Text(detail) }
    }
}

struct ErrorBanner: View {
    let message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle.fill").font(.footnote).foregroundStyle(.white).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.red.gradient, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct SearchBar: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search", text: $text).textInputAutocapitalization(.never)
            if !text.isEmpty { Button { text = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }.buttonStyle(.plain) }
        }.padding(.horizontal, 13).frame(height: 42).background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 13))
    }
}

struct SettingsRow<Trailing: View>: View {
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white).frame(width: 31, height: 31).background(color.gradient, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.body.weight(.medium)); if let subtitle, !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2) } }
            Spacer(minLength: 8); trailing
        }.contentShape(Rectangle()).padding(.vertical, 4)
    }
}

extension SettingsRow where Trailing == AnyView {
    init(icon: String, color: Color, title: LocalizedStringKey, subtitle: String? = nil) {
        self.init(icon: icon, color: color, title: title, subtitle: subtitle) { AnyView(Image(systemName: "chevron.forward").font(.caption.weight(.bold)).foregroundStyle(.tertiary)) }
    }
}

struct AgentToolRow: View {
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon).font(.title3.weight(.semibold)).foregroundStyle(color).frame(width: 46, height: 46).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(2) }
            Spacer(); Image(systemName: "chevron.forward").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
        }.padding(.vertical, 5).contentShape(Rectangle())
    }
}

struct MarkdownText: View {
    let text: String
    var body: some View {
        Group {
            if let value = Self.attributed(text) {
                Text(value)
            } else {
                Text(text)
            }
        }
        .multilineTextAlignment(Self.layoutDirection(for: text) == .rightToLeft ? .trailing : .leading)
        .environment(\.layoutDirection, Self.layoutDirection(for: text))
        .textSelection(.enabled)
    }

    static func attributed(_ source: String) -> AttributedString? {
        // SwiftUI.Text ignores Markdown block presentation intents. Parsing the
        // full document therefore collapsed paragraphs and lists into one run.
        // Inline parsing keeps bold, links and code while preserving every line
        // break and list marker exactly as the agent sent it.
        try? AttributedString(
            markdown: source,
            options: .init(
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        )
    }

    static func layoutDirection(for source: String) -> LayoutDirection {
        for scalar in source.unicodeScalars {
            switch scalar.value {
            case 0x0590...0x08FF, 0xFB1D...0xFDFF, 0xFE70...0xFEFF:
                return .rightToLeft
            default:
                if CharacterSet.letters.contains(scalar) { return .leftToRight }
            }
        }
        return .leftToRight
    }
}

struct FileDownloadCard: View {
    let link: DownloadLink
    let url: URL?
    @State private var localURL: URL?
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        Button { Task { await download() } } label: {
            HStack(spacing: 12) {
                Image(systemName: fileIcon).font(.title3).foregroundStyle(HermesTheme.purple).frame(width: 40, height: 40).background(HermesTheme.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 3) { Text(link.label).font(.subheadline.weight(.semibold)).lineLimit(2); Text(ChatFiles.fileName(for: link)).font(.caption).foregroundStyle(.secondary).lineLimit(1) }
                Spacer(); if loading { ProgressView() } else { Image(systemName: "arrow.down.circle.fill").font(.title3).foregroundStyle(HermesTheme.purple) }
            }.padding(11).background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
        }.buttonStyle(.plain).quickLookPreview($localURL)
        if let error { Text(error).font(.caption2).foregroundStyle(.red) }
    }

    private var fileIcon: String {
        let ext = URL(fileURLWithPath: link.path).pathExtension.lowercased()
        if ["png", "jpg", "jpeg", "webp", "gif"].contains(ext) { return "photo" }
        if ext == "pdf" { return "doc.richtext" }
        if ["ppt", "pptx"].contains(ext) { return "rectangle.on.rectangle.angled" }
        if ["zip", "tar", "gz"].contains(ext) { return "archivebox" }
        return "doc"
    }

    private func download() async {
        guard let url else { error = String(localized: "Download link is unavailable"); return }
        loading = true; defer { loading = false }
        do {
            let (temporary, response) = try await URLSession.shared.download(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) { throw HermesError.http(http.statusCode, "") }
            let destination = FileManager.default.temporaryDirectory.appendingPathComponent(ChatFiles.fileName(for: link))
            try? FileManager.default.removeItem(at: destination); try FileManager.default.copyItem(at: temporary, to: destination)
            localURL = destination; error = nil
        } catch { self.error = error.localizedDescription }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300; var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for view in subviews { let size = view.sizeThatFits(.unspecified); if x + size.width > width && x > 0 { x = 0; y += row + spacing; row = 0 }; x += size.width + spacing; row = max(row, size.height) }
        return CGSize(width: width, height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for view in subviews { let size = view.sizeThatFits(.unspecified); if x + size.width > bounds.maxX && x > bounds.minX { x = bounds.minX; y += row + spacing; row = 0 }; view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size)); x += size.width + spacing; row = max(row, size.height) }
    }
}
