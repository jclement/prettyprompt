// The contract between the command line and the window.
//
// A PromptSpec is everything the UI needs and nothing it doesn't: no
// ArgumentParser types, no file paths, no exit codes. The commands build one,
// the presenter shows it, and a PromptOutcome comes back. Anything that can be
// decided before a window opens is decided before a window opens.

import CoreGraphics
import Foundation

/// One selectable row in a `choose` prompt.
struct ChoiceOption: Equatable {
    /// What gets printed if this row is picked.
    let value: String
    /// Optional second line, shown dimmed under the value.
    let detail: String?

    /// Parses one option as written on the command line or piped in.
    ///
    /// A tab splits the printable value from a description — chosen because it
    /// survives shell quoting and is what `cut`, `awk` and friends already emit:
    ///   printf 'prod\tRestarts 3 services\n' | prettyprompt choose "Where?"
    init(rawValue: String) {
        let parts = rawValue.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
        value = String(parts[0])
        let description =
            parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespaces) : ""
        detail = description.isEmpty ? nil : description
    }
}

/// Which kind of prompt to draw, plus the settings only that kind cares about.
enum PromptKind: Equatable {
    case choose(ChooseSpec)
    case input(InputSpec)
    case confirm(ConfirmSpec)
    case alert(buttonLabel: String)
}

struct ChooseSpec: Equatable {
    var options: [ChoiceOption]
    /// Checkboxes and a submit button instead of pick-and-go.
    var allowsMultiple: Bool = false
    /// Indexes into `options` that start selected.
    var preselected: Set<Int> = []
    /// Maximum number of rows selectable at once; nil means no limit. Ignored
    /// unless `allowsMultiple`.
    var limit: Int?
    /// Show the filter field. Long lists get one automatically; this forces it.
    var forceFilter: Bool = false
}

struct InputSpec: Equatable {
    var placeholder: String?
    var initialValue: String = ""
    /// Masked entry. Also suppresses the value from any error output.
    var secure: Bool = false
    /// A resizable text area; Enter inserts a newline and ⌘↩ submits.
    var multiline: Bool = false
    /// Reject an empty answer rather than returning "".
    var requiresValue: Bool = false
}

struct ConfirmSpec: Equatable {
    var affirmative: String = "OK"
    var negative: String = "Cancel"
    /// Which button is focused, and what Enter does.
    var defaultsToYes: Bool = true
    /// Paints the affirmative button in the theme's danger colour.
    var destructive: Bool = false
}

/// Which display the panel opens on.
enum ScreenChoice: Equatable {
    /// The screen the pointer is on — "the one you're looking at" in practice,
    /// and the default.
    case mouse
    /// The screen owning the currently focused window.
    case focused
    /// A specific screen by position in the system's display list, 0-based.
    case index(Int)

    /// Parses the `--screen` value, or nil if it is not a valid choice.
    init?(argument: String) {
        switch argument.lowercased() {
        case "mouse", "pointer", "cursor": self = .mouse
        case "focused", "active", "main": self = .focused
        default:
            guard let position = Int(argument), position >= 0 else { return nil }
            self = .index(position)
        }
    }
}

/// What to do when `--timeout` runs out.
enum TimeoutBehaviour: String, Equatable {
    /// Give up: print nothing, exit 124. The safe default.
    case cancel
    /// Submit whatever is currently selected or typed.
    case accept
}

/// A complete, ready-to-show prompt.
struct PromptSpec {
    var title: String
    /// Supporting line under the title.
    var message: String?
    /// An emoji, or an SF Symbol name like `exclamationmark.triangle.fill`.
    var icon: String?
    var kind: PromptKind
    var theme: Theme
    var width: CGFloat
    var timeout: TimeInterval?
    var timeoutBehaviour: TimeoutBehaviour = .cancel
    /// Removes Esc and every other way out. The caller gets an answer.
    var insist: Bool = false
    /// Play the system alert sound as the panel appears.
    var sound: Bool = false
    var screen: ScreenChoice = .mouse
}
