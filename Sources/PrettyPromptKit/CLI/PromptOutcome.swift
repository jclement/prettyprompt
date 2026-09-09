// What a prompt produced, and how that reaches the caller.
//
// The UI layer's whole job is to return one of these; everything about stdout
// formatting and exit codes is decided here, once, for every command. Keeping
// it out of the views is what makes the shell contract testable without
// opening a window.

import Foundation

/// The result of showing one prompt.
enum PromptOutcome: Equatable {
    /// A text answer (`input`).
    case text(String)
    /// One or more chosen options, with their positions in the original list so
    /// `--index` can report them without a second lookup.
    case chosen(values: [String], indexes: [Int])
    /// A yes/no answer (`confirm`).
    case confirmed(Bool)
    /// An `alert` was dismissed by the user.
    case acknowledged
    /// The user pressed Esc, or closed the panel.
    case cancelled
    /// `--timeout` elapsed with no default to fall back on.
    case timedOut

    var exitCode: Int32 {
        switch self {
        case .text, .chosen, .acknowledged: return PromptExit.success
        case let .confirmed(yes): return yes ? PromptExit.success : PromptExit.declined
        case .cancelled: return PromptExit.cancelled
        case .timedOut: return PromptExit.timedOut
        }
    }
}

/// Renders an outcome for stdout.
///
/// Plain output is deliberately bare — the answer and nothing else — so that
/// `name=$(prettyprompt input "Name?")` needs no trimming. Cancellation and
/// timeout print nothing at all in plain mode; the exit code carries them.
enum OutcomeWriter {
    /// The stdout text for an outcome, or nil when nothing should be printed.
    ///
    /// - Parameters:
    ///   - outcome: what the prompt produced.
    ///   - json: emit a single JSON object instead of bare values.
    ///   - useIndexes: for `chosen`, print positions rather than values.
    /// - Returns: the exact text to print, without a trailing newline, or nil
    ///   when the exit code carries the whole answer.
    static func render(_ outcome: PromptOutcome, json: Bool, useIndexes: Bool = false) -> String? {
        guard json else { return plainText(outcome, useIndexes: useIndexes) }
        return jsonText(outcome, useIndexes: useIndexes)
    }

    private static func plainText(_ outcome: PromptOutcome, useIndexes: Bool) -> String? {
        switch outcome {
        case let .text(value):
            return value
        case let .chosen(values, indexes):
            return useIndexes
                ? indexes.map(String.init).joined(separator: "\n")
                : values.joined(separator: "\n")
        // A yes/no answer and an acknowledged alert are fully carried by the
        // exit code; printing "true" would only ever be something to strip.
        case .confirmed, .acknowledged, .cancelled, .timedOut:
            return nil
        }
    }

    private static func jsonText(_ outcome: PromptOutcome, useIndexes: Bool) -> String? {
        var payload: [String: Any] = [:]
        switch outcome {
        case let .text(value):
            payload = ["status": "ok", "value": value]
        case let .chosen(values, indexes):
            payload = [
                "status": "ok",
                "values": values,
                "indexes": indexes,
                // `value` is the convenience field for the common
                // single-select case; null when nothing was selected.
                "value": values.first as Any? ?? NSNull(),
            ]
            if useIndexes { payload["value"] = indexes.first as Any? ?? NSNull() }
        case let .confirmed(yes):
            payload = ["status": "ok", "confirmed": yes]
        case .acknowledged:
            payload = ["status": "ok", "acknowledged": true]
        case .cancelled:
            payload = ["status": "cancelled"]
        case .timedOut:
            payload = ["status": "timeout"]
        }
        guard
            let data = try? JSONSerialization.data(
                withJSONObject: payload,
                options: [.sortedKeys]),
            let text = String(data: data, encoding: .utf8)
        else { return nil }
        return text
    }
}
