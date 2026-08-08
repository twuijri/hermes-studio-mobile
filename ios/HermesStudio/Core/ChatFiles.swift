import Foundation

enum ChatFiles {
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
