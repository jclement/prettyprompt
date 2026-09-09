// `prettyprompt themes` — list what's available, or try one on.
//
// Listing goes to stdout as plain text because it is the kind of thing that
// gets piped into grep. The demo opens a real prompt, because the only honest
// way to preview a theme is to look at it.

import ArgumentParser
import Foundation

struct ThemesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "themes",
        abstract: "List the available themes, or preview one.",
        discussion: """
            With no argument, prints every theme name and description. With a name, \
            opens a sample prompt drawn in that theme.

            Custom themes are JSON files in \(Paths.themesDirectory.path); the name \
            is the file name without .json. Run `prettyprompt themes --export dark` \
            to print a built-in as a starting point.
            """)

    @Argument(help: ArgumentHelp("Preview this theme.", valueName: "name"))
    var name: String?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Print a theme as JSON, ready to edit into your own.", valueName: "name"))
    var export: String?

    @Flag(name: .long, help: "Print the list as JSON.")
    var json = false

    func run() throws {
        if let export {
            try printThemeJSON(named: export)
            return
        }
        guard let name else {
            try printList()
            return
        }
        try preview(named: name)
    }

    private func printList() throws {
        let custom = ThemeLoader.customNames()
        guard !json else {
            let rows =
                BuiltInThemes.all.map {
                    ["name": $0.name, "summary": $0.summary, "builtin": true] as [String: Any]
                }
                + custom.map {
                    ["name": $0, "summary": "Custom theme", "builtin": false] as [String: Any]
                }
            let data = try JSONSerialization.data(
                withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            print(String(decoding: data, as: UTF8.self))
            return
        }

        let width = BuiltInThemes.all.map(\.name.count).max() ?? 8
        for theme in BuiltInThemes.all {
            print(
                "  \(theme.name.padding(toLength: width, withPad: " ", startingAt: 0))  \(theme.summary)"
            )
        }
        guard !custom.isEmpty else { return }
        print("\n  Custom (\(Paths.themesDirectory.path)):")
        for name in custom {
            print("  \(name)")
        }
    }

    private func printThemeJSON(named name: String) throws {
        let theme = try ThemeLoader.resolve(name)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        print(String(decoding: try encoder.encode(theme), as: UTF8.self))
    }

    /// Opens a sample `choose` prompt so the theme can be judged in the shape
    /// it will actually be used in.
    private func preview(named name: String) throws {
        let theme = try ThemeLoader.resolve(name)
        let spec = PromptSpec(
            title: "The \(theme.name) theme",
            message: theme.summary,
            icon: "paintpalette.fill",
            kind: .choose(
                ChooseSpec(options: [
                    ChoiceOption(rawValue: "Looks great\tKeep this one"),
                    ChoiceOption(rawValue: "Too loud\tTry something quieter"),
                    ChoiceOption(rawValue: "Not loud enough\tTry doom or hotdog"),
                ])),
            theme: theme,
            width: CGFloat(PresentationOptions.defaultWidth))
        let outcome = PromptPresenter.present(spec)
        if case let .chosen(values, _) = outcome, let first = values.first {
            print(first)
        }
        Foundation.exit(outcome.exitCode)
    }
}
