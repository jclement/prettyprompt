// Reading options from a pipe.
//
// `choose` accepts its list either as --option flags or on stdin, so that
// prettyprompt composes with the rest of the shell:
//   git branch --format='%(refname:short)' | prettyprompt choose "Check out?"

import Foundation

enum StandardInput {
    /// True when stdin is a terminal, meaning nobody piped anything in and
    /// reading would block forever waiting for the user to type.
    static var isTerminal: Bool {
        isatty(FileHandle.standardInput.fileDescriptor) == 1
    }

    /// Every non-empty line on stdin, trailing newline removed.
    /// Returns an empty array when stdin is a terminal rather than blocking.
    static func lines() -> [String] {
        guard !isTerminal else { return [] }
        guard let data = try? FileHandle.standardInput.readToEnd(),
            let text = String(data: data, encoding: .utf8)
        else { return [] }
        return
            text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: CharacterSet(charactersIn: "\r")) }
            .filter { !$0.isEmpty }
    }
}
