// Markdown in prompt bodies.
//
// A prompt often needs to say more than one flat sentence — "this will drop
// **3 tables**", a bulleted list of what is about to happen, a `command` you
// are about to run. SwiftUI's AttributedString handles the inline syntax; the
// block structure (newlines, bullets, fenced code) is parsed here, because
// AttributedString's markdown support collapses all of it.
//
// Supported: **bold**, *italic*, `code`, [links](https://…), - bullets,
// ``` fenced blocks, and blank lines as paragraph breaks. Deliberately not a
// full markdown implementation — headings and tables have no place in a prompt.

import SwiftUI

/// One line's worth of structure, before inline styling is applied.
enum MarkdownBlock: Equatable {
    /// A line of prose.
    case paragraph(String)
    /// A `- `, `* ` or `• ` line, with the marker stripped.
    case bullet(String)
    /// The contents of a ``` fence, newlines intact.
    case code(String)
    /// A blank line between blocks.
    case gap
}

enum Markdown {
    /// Splits source text into blocks.
    ///
    /// Each line stands alone rather than being reflowed into a paragraph the
    /// way real markdown would: a caller who wrote a newline in their --message
    /// meant it.
    static func blocks(from source: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var fencedLines: [String]?

        for rawLine in source.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: CharacterSet(charactersIn: "\r"))

            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                if let collected = fencedLines {
                    blocks.append(.code(collected.joined(separator: "\n")))
                    fencedLines = nil
                } else {
                    fencedLines = []
                }
                continue
            }
            if fencedLines != nil {
                fencedLines?.append(line)
                continue
            }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                // Collapse runs of blank lines; one gap is a paragraph break,
                // three is just sloppy input.
                if blocks.last != .gap, !blocks.isEmpty { blocks.append(.gap) }
            } else if let item = bulletContent(of: trimmed) {
                blocks.append(.bullet(item))
            } else {
                blocks.append(.paragraph(trimmed))
            }
        }

        // An unclosed fence still renders — better than swallowing the text.
        if let collected = fencedLines, !collected.isEmpty {
            blocks.append(.code(collected.joined(separator: "\n")))
        }
        return blocks
    }

    /// The text after a bullet marker, or nil if the line isn't a bullet.
    private static func bulletContent(of line: String) -> String? {
        for marker in ["- ", "* ", "• "] where line.hasPrefix(marker) {
            return String(line.dropFirst(marker.count))
        }
        return nil
    }

    /// Applies inline markdown and the theme's own styling for code and links.
    ///
    /// Falls back to the raw string when the source isn't valid markdown, so a
    /// stray bracket shows the user's text rather than nothing.
    static func inline(_ source: String, ui: ThemeContext) -> AttributedString {
        // .inlineOnlyPreservingWhitespace stops AttributedString from eating
        // the spacing we have already decided about.
        guard
            var attributed = try? AttributedString(
                markdown: source,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))
        else { return AttributedString(source) }

        for run in attributed.runs {
            if run.inlinePresentationIntent?.contains(.code) == true {
                attributed[run.range].font = .system(
                    size: 12, weight: .regular, design: .monospaced)
                attributed[run.range].backgroundColor = ui.palette.surface.opacity(0.9).color
                attributed[run.range].foregroundColor = ui.palette.foreground.color
            }
            if run.link != nil {
                attributed[run.range].foregroundColor = ui.palette.accent.color
                attributed[run.range].underlineStyle = .single
            }
        }
        return attributed
    }
}

/// Renders markdown source as a stack of blocks.
struct RichText: View {
    @Environment(\.ui) private var ui
    let source: String
    /// Colour for plain prose. Code and links override it themselves.
    var color: ThemeColor?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(Markdown.blocks(from: source).enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
    }

    @ViewBuilder private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case let .paragraph(text):
            Text(Markdown.inline(text, ui: ui))
                .font(ui.bodyFont)
                .foregroundStyle(foreground)
                .fixedSize(horizontal: false, vertical: true)

        case let .bullet(text):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("•")
                    .font(ui.bodyFont)
                    .foregroundStyle(ui.palette.accent.color)
                Text(Markdown.inline(text, ui: ui))
                    .font(ui.bodyFont)
                    .foregroundStyle(foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.leading, 2)

        case let .code(text):
            Text(text)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .foregroundStyle(ui.palette.foreground.color)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: ui.controlRadius, style: .continuous)
                        .fill(ui.palette.surface.opacity(0.9).color)
                )
                .padding(.vertical, 2)

        case .gap:
            Spacer().frame(height: 5)
        }
    }

    private var foreground: Color {
        (color ?? ui.palette.secondary).color
    }
}
