// The exit-code contract.
//
// This is the part of prettyprompt that shell scripts actually program against,
// so it is deliberately small, stable and documented in the README. The one
// non-obvious choice: 1 means "the user said no", not "something broke".
// Runtime failures use 70 (EX_SOFTWARE) so that `confirm` can spend 1 on a real
// answer and `if prettyprompt confirm ...; then` reads correctly.

import Foundation

public enum PromptExit {
    /// An answer was given. For `confirm`, the answer was yes.
    public static let success: Int32 = 0
    /// `confirm` only: the user answered no. Never used by other commands.
    public static let declined: Int32 = 1
    /// Bad flags, unknown theme, no options to choose from.
    public static let usage: Int32 = 2
    /// `--timeout` elapsed and no `--default` was supplied.
    public static let timedOut: Int32 = 124
    /// The user dismissed the prompt with Esc or ⌘.
    public static let cancelled: Int32 = 130
    /// Something went wrong that is not the caller's fault.
    public static let internalError: Int32 = 70
}

/// Every failure prettyprompt reports to the shell.
///
/// Messages are written for someone reading a terminal, so they say what to do
/// next rather than what the code hit.
public enum PromptError: Error {
    case unknownTheme(name: String, available: [String])
    case badTheme(path: String, reason: String)
    case badConfig(path: String, reason: String)
    case noOptions
    case unknownDefault(value: String)
    case unknownSound(name: String, available: [String])
    case cannotConnectToWindowServer

    public var message: String {
        switch self {
        case let .unknownTheme(name, available):
            return """
                Unknown theme "\(name)".
                Available: \(available.joined(separator: ", "))
                Add your own as \(Paths.themesDirectory.path)/<name>.json
                """
        case let .badTheme(path, reason):
            return "Could not read theme \(path): \(reason)"
        case let .badConfig(path, reason):
            return "Could not read config \(path): \(reason)"
        case .noOptions:
            return """
                No options to choose from.
                Pass them with --option, or pipe them in one per line:
                  printf 'one\\ntwo\\n' | prettyprompt choose "Pick one"
                """
        case let .unknownDefault(value):
            return "--default \"\(value)\" is not one of the options."
        case let .unknownSound(name, available):
            return """
                Unknown sound "\(name)".
                Available: \(available.joined(separator: ", "))
                """
        case .cannotConnectToWindowServer:
            return """
                Cannot open a window — there is no macOS session to draw into.
                prettyprompt needs a logged-in desktop; it will not work over a bare
                SSH session or from a launchd daemon running as root.
                """
        }
    }

    public var exitCode: Int32 {
        switch self {
        case .cannotConnectToWindowServer: return PromptExit.internalError
        default: return PromptExit.usage
        }
    }
}
