// Where prettyprompt keeps things on disk.
//
// XDG throughout, honouring XDG_CONFIG_HOME when it is set so a test or a
// sandboxed run can point the whole app at a scratch directory.

import Foundation

enum Paths {
    /// `$XDG_CONFIG_HOME/prettyprompt`, or `~/.config/prettyprompt`.
    static var configDirectory: URL {
        let base: URL
        if let override = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], !override.isEmpty
        {
            base = URL(fileURLWithPath: override, isDirectory: true)
        } else {
            base = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".config", isDirectory: true)
        }
        return base.appendingPathComponent("prettyprompt", isDirectory: true)
    }

    static var configFile: URL {
        configDirectory.appendingPathComponent("config.json")
    }

    /// User themes live one file per theme, named after the file stem, so
    /// `doom-lite.json` is selected with `--theme doom-lite`.
    static var themesDirectory: URL {
        configDirectory.appendingPathComponent("themes", isDirectory: true)
    }
}
