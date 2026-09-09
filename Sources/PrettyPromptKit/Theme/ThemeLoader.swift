// Turning a --theme name into a Theme.
//
// Built-ins are checked first, then ~/.config/prettyprompt/themes/<name>.json.
// A user file may shadow nothing: built-in names win, so `--theme dark` always
// means the same thing on every machine.

import Foundation

enum ThemeLoader {
    /// Resolves a theme by name.
    ///
    /// Throws `PromptError.unknownTheme` with the list of valid names when the
    /// name matches neither a built-in nor a file — a typo should tell you what
    /// you could have typed instead.
    static func resolve(
        _ name: String, themesDirectory: URL = Paths.themesDirectory
    ) throws -> Theme {
        if let builtIn = BuiltInThemes.named(name) { return builtIn }

        let file = themesDirectory.appendingPathComponent("\(name).json")
        guard let data = try? Data(contentsOf: file) else {
            throw PromptError.unknownTheme(
                name: name,
                available: availableNames(in: themesDirectory))
        }
        do {
            var theme = try JSONDecoder().decode(Theme.self, from: data)
            // The file name is the identity a user types, so it wins over a
            // stale "name" left inside a copied-and-edited file.
            theme.name = name
            return theme
        } catch {
            throw PromptError.badTheme(path: file.path, reason: error.localizedDescription)
        }
    }

    /// Built-in names followed by user theme names, both in display order.
    static func availableNames(in themesDirectory: URL = Paths.themesDirectory) -> [String] {
        BuiltInThemes.all.map(\.name) + customNames(in: themesDirectory)
    }

    /// Theme names found on disk, excluding any that collide with a built-in.
    static func customNames(in themesDirectory: URL = Paths.themesDirectory) -> [String] {
        let contents =
            (try? FileManager.default.contentsOfDirectory(
                at: themesDirectory, includingPropertiesForKeys: nil)) ?? []
        return
            contents
            .filter { $0.pathExtension == "json" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .filter { BuiltInThemes.named($0) == nil }
            .sorted()
    }
}
