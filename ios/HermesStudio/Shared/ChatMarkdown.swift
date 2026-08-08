import SwiftUI

/// The Markdown subset emitted by Hermes agents. SwiftUI's `Text` supports
/// inline Markdown but ignores block presentation such as headings and lists,
/// so chat messages need a small block renderer of their own.
enum ChatMarkdownBlock: Equatable {
    case paragraph(String)
    case heading(level: Int, text: String)
    case unordered(indent: Int, text: String)
    case ordered(indent: Int, marker: String, text: String)
    case quote(String)
    case code(String)

    var text: String {
        switch self {
        case let .paragraph(text), let .quote(text), let .code(text): text
        case let .heading(_, text), let .unordered(_, text), let .ordered(_, _, text): text
        }
    }
}

enum ChatMarkdownParser {
    static func parse(_ source: String) -> [ChatMarkdownBlock] {
        let normalized = source
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var blocks: [ChatMarkdownBlock] = []
        var paragraph: [String] = []
        var code: [String] = []
        var inFence = false

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append(.paragraph(paragraph.joined(separator: "\n")))
            paragraph.removeAll(keepingCapacity: true)
        }

        func flushCode() {
            guard !code.isEmpty else { return }
            blocks.append(.code(code.joined(separator: "\n")))
            code.removeAll(keepingCapacity: true)
        }

        for raw in lines {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") || trimmed.hasPrefix("~~~") {
                flushParagraph()
                if inFence { flushCode() }
                inFence.toggle()
                continue
            }
            if inFence { code.append(raw); continue }
            if trimmed.isEmpty { flushParagraph(); continue }

            if let heading = heading(from: trimmed) {
                flushParagraph()
                blocks.append(.heading(level: heading.level, text: heading.text))
            } else if let item = unorderedItem(from: raw) {
                flushParagraph()
                blocks.append(.unordered(indent: item.indent, text: item.text))
            } else if let item = orderedItem(from: raw) {
                flushParagraph()
                blocks.append(.ordered(indent: item.indent, marker: item.marker, text: item.text))
            } else if trimmed.hasPrefix("> ") {
                flushParagraph()
                blocks.append(.quote(String(trimmed.dropFirst(2))))
            } else {
                paragraph.append(trimmed)
            }
        }
        flushParagraph()
        flushCode()
        return blocks
    }

    private static func heading(from line: String) -> (level: Int, text: String)? {
        let count = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(count), line.dropFirst(count).first == " " else { return nil }
        return (count, String(line.dropFirst(count + 1)))
    }

    private static func unorderedItem(from line: String) -> (indent: Int, text: String)? {
        let spaces = line.prefix(while: { $0 == " " || $0 == "\t" }).reduce(into: 0) { count, char in
            count += char == "\t" ? 2 : 1
        }
        let value = line.drop(while: { $0 == " " || $0 == "\t" })
        guard let marker = value.first, ["-", "*", "+", "•", "◦"].contains(marker), value.dropFirst().first == " " else { return nil }
        return (spaces / 2, String(value.dropFirst(2)))
    }

    private static func orderedItem(from line: String) -> (indent: Int, marker: String, text: String)? {
        let spaces = line.prefix(while: { $0 == " " || $0 == "\t" }).reduce(into: 0) { count, char in
            count += char == "\t" ? 2 : 1
        }
        let value = String(line.drop(while: { $0 == " " || $0 == "\t" }))
        let digits = value.prefix(while: \Character.isNumber)
        guard !digits.isEmpty else { return nil }
        let suffix = value.dropFirst(digits.count)
        guard let punctuation = suffix.first, punctuation == "." || punctuation == ")", suffix.dropFirst().first == " " else { return nil }
        return (spaces / 2, "\(digits)\(punctuation)", String(suffix.dropFirst(2)))
    }
}

struct MarkdownText: View {
    let text: String

    var body: some View {
        let blocks = ChatMarkdownParser.parse(text)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                blockView(block)
                    .padding(.top, index == 0 ? 0 : spacing(before: block, after: blocks[index - 1]))
            }
        }
        // Keep the container physical LTR. Each paragraph independently opts
        // into RTL, which is what lets Arabic end at the actual right edge even
        // when the rest of the app is currently English.
        .environment(\.layoutDirection, .leftToRight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: ChatMarkdownBlock) -> some View {
        switch block {
        case let .heading(level, text):
            DirectionalMarkdownLine(text: text, font: headingFont(level))
        case let .unordered(indent, text):
            listRow(marker: "◦", text: text, indent: indent, subtleMarker: true)
        case let .ordered(indent, marker, text):
            listRow(marker: marker, text: text, indent: indent, subtleMarker: false)
        case let .quote(text):
            DirectionalMarkdownLine(text: text)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 8))
        case let .code(text):
            DirectionalMarkdownLine(text: text, isCode: true)
                .padding(9)
                .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 9))
        case let .paragraph(text):
            DirectionalMarkdownLine(text: text)
        }
    }

    @ViewBuilder
    private func listRow(marker: String, text: String, indent: Int, subtleMarker: Bool) -> some View {
        let direction = Self.layoutDirection(for: text)
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            if direction == .rightToLeft {
                DirectionalMarkdownLine(text: text)
                listMarker(marker, subtle: subtleMarker)
            } else {
                listMarker(marker, subtle: subtleMarker)
                DirectionalMarkdownLine(text: text)
            }
        }
        .padding(direction == .rightToLeft ? .trailing : .leading, CGFloat(indent) * 16)
        .frame(maxWidth: .infinity, alignment: direction == .rightToLeft ? .trailing : .leading)
        .environment(\.layoutDirection, .leftToRight)
    }

    private func listMarker(_ marker: String, subtle: Bool) -> some View {
        Text(marker)
            .font(subtle ? .system(size: 13, weight: .semibold) : .body.monospacedDigit())
            .foregroundStyle(subtle ? .secondary : .primary)
            .accessibilityHidden(true)
    }

    private func headingFont(_ level: Int) -> Font {
        switch level {
        case 1: .title.bold()
        case 2: .title2.bold()
        case 3: .title3.bold()
        default: .subheadline.bold()
        }
    }

    private func spacing(before current: ChatMarkdownBlock, after previous: ChatMarkdownBlock) -> CGFloat {
        switch (previous, current) {
        case (_, .heading): 14
        case (.heading, _): 7
        case (.unordered, .unordered), (.unordered, .ordered), (.ordered, .unordered), (.ordered, .ordered): 4
        case (.unordered, _), (.ordered, _): 11
        case (_, .unordered), (_, .ordered): 7
        default: 9
        }
    }

    static func attributed(_ source: String) -> AttributedString? {
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

private struct DirectionalMarkdownLine: View {
    let text: String
    var isCode = false
    var font: Font = .body

    var body: some View {
        let direction = MarkdownText.layoutDirection(for: text)
        Group {
            if let value = MarkdownText.attributed(text) { Text(value) } else { Text(text) }
        }
        .font(isCode ? .callout.monospaced() : font)
        .lineSpacing(3)
        // Alignment is semantic inside the paragraph environment: `.leading`
        // is the physical right edge for RTL and the physical left edge for
        // LTR. Using `.trailing` here pushed wrapped Arabic lines to the left.
        .multilineTextAlignment(.leading)
        .environment(\.layoutDirection, direction)
        .frame(maxWidth: .infinity, alignment: direction == .rightToLeft ? .trailing : .leading)
        .environment(\.layoutDirection, .leftToRight)
    }
}
