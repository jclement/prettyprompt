// Defaults read from ~/.config/prettyprompt/config.json.
//
// Every field is optional and every field has a command-line counterpart that
// wins. The file exists so a user can set `"theme": "doom"` once instead of
// threading --theme through a hundred shell scripts.

import Foundation

struct Config: Codable, Equatable {
    var theme: String?
    var width: Double?
    var sound: Bool?
    /// Overrides each theme's own sound. Validated when a prompt is built, so a
    /// typo here is reported rather than silently ignored.
    var soundName: String?
    var screen: String?
    /// Seconds. A global timeout is a safety net for scripts that run
    /// unattended — it is off unless set.
    var timeout: Double?

    static let empty = Config()

    /// Loads the config file, or returns empty defaults.
    ///
    /// A malformed config is reported rather than swallowed: silently ignoring
    /// it would leave the user staring at the wrong theme with no explanation.
    static func load(from url: URL = Paths.configFile) throws -> Config {
        guard let data = try? Data(contentsOf: url) else { return .empty }
        do {
            return try JSONDecoder().decode(Config.self, from: data)
        } catch {
            throw PromptError.badConfig(path: url.path, reason: error.localizedDescription)
        }
    }
}
