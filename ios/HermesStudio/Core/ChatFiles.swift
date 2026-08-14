import Foundation

struct ParsedChatMessage {
    let text: String
    let files: [DownloadLink]
}

enum ChatFiles {
    /// Studio persists uploaded files as JSON content blocks. Decode that
    /// storage format before rendering so voice notes and documents remain
    /// native attachment cards after a refresh.
    static func parse(_ content: String) -> ParsedChatMessage {
        guard let data = content.trimmingCharacters(in: .whitespacesAndNewlines).data(using: .utf8),
              let blocks = try? JSONSerialization.jsonObject(with: data) as? [JSON]
        else { return ParsedChatMessage(text: content, files: links(in: content)) }

        var recognized = false
        var text: [String] = []
        var files: [DownloadLink] = []
        for block in blocks {
            switch block.string("type") {
            case "text":
                recognized = true
                if let value = block.string("text").nilIfEmpty { text.append(value) }
            case "file", "image":
                recognized = true
                let path = block.string("path")
                guard path.hasPrefix("/") || path.hasPrefix("~") else { continue }
                let name = block.string("name").nilIfEmpty ?? URL(fileURLWithPath: path).lastPathComponent
                if !files.contains(where: { $0.path == path }) {
                    files.append(DownloadLink(label: name, path: path))
                }
            default:
                continue
            }
        }
        guard recognized else { return ParsedChatMessage(text: content, files: links(in: content)) }
        let body = text.joined(separator: "\n\n")
        for link in links(in: body) where !files.contains(where: { $0.path == link.path }) { files.append(link) }
        return ParsedChatMessage(text: body, files: files)
    }

    // Accepts both standard Markdown and the malformed (>path>) form emitted by a few agents.
    static func links(in text: String) -> [DownloadLink] {
        let patterns = [
            #"\[([^\]]+)\]\(<?(?:file://)?([^\)<>]+)>?\)"#,
            #"\[([^\]]+)\]\(<?(?:file://)?([^\)]+)\)"#,
        ]
        var result: [DownloadLink] = []
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) where match.numberOfRanges >= 3 {
                guard let labelRange = Range(match.range(at: 1), in: text), let pathRange = Range(match.range(at: 2), in: text) else { continue }
                let label = String(text[labelRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                let path = String(text[pathRange]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "<>")))
                guard path.hasPrefix("/") || path.hasPrefix("~") else { continue }
                if !result.contains(where: { $0.path == path }) { result.append(DownloadLink(label: label, path: path)) }
            }
        }
        return result
    }

    static func fileName(for link: DownloadLink) -> String {
        let pathName = URL(fileURLWithPath: link.path).lastPathComponent
        return pathName.isEmpty ? link.label : pathName
    }
}
