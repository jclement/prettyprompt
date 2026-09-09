// The command tree.
//
// Each subcommand does the same three things: turn its flags into a PromptKind,
// hand the spec to the presenter, and let `emit` deal with stdout and the exit
// code. Nothing here draws anything.

import ArgumentParser
import Foundation

public struct RootCommand: ParsableCommand {
    public init() {}

    public static let configuration = CommandConfiguration(
        commandName: "prettyprompt",
        abstract: "Beautiful macOS prompts for shell scripts.",
        discussion: """
            Puts a themed panel dead centre on the display you are looking at, \
            above everything else, and prints the answer to stdout. Built to be \
            called from shell scripts, Makefiles, git hooks and agents.

            EXAMPLES
              # a yes/no gate, straight into an if
              if prettyprompt confirm "Ship it?" --theme danger; then
                ./deploy.sh
              fi

              # pick a branch, fed from git
              branch=$(git branch | prettyprompt choose "Check out?")

              # ask for something, with a deadline
              name=$(prettyprompt input "Branch name?" -t 60) || exit 1

              # tick off several things at once
              prettyprompt choose "Include?" --multiple -o Formula -o Notes

              # interrupt a long build
              make || prettyprompt alert "Build failed" --icon ⚠️ --sound

            EXIT CODES
              0    answered  (confirm: yes)
              1    confirm: no — an answer, not an error
              2    usage error
              70   no window server, or an unreadable config
              124  --timeout elapsed
              130  cancelled with Esc

            A cancelled or timed-out prompt prints nothing at all, so a bare \
            $(...) capture is always either a real answer or empty.

            FILES
              ~/.config/prettyprompt/config.json    theme, width, timeout
              ~/.config/prettyprompt/themes/*.json  your own themes

            Run `prettyprompt themes` for the eleven built-in looks, and \
            `prettyprompt help <subcommand>` for one prompt in detail.
            """,
        version: Version.full,
        subcommands: [
            ChooseCommand.self, InputCommand.self, ConfirmCommand.self,
            AlertCommand.self, ThemesCommand.self,
        ])
}

/// Shows a prompt, prints its answer, and exits with the contract's code.
/// Never returns.
func emit(_ spec: PromptSpec, json: Bool, useIndexes: Bool = false) -> Never {
    let outcome = PromptPresenter.present(spec)
    if let text = OutcomeWriter.render(outcome, json: json, useIndexes: useIndexes) {
        print(text)
    }
    exit(outcome.exitCode)
}

// ---- choose ----

struct ChooseCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "choose",
        abstract: "Pick one option, or several.",
        discussion: """
            Options come from repeated --option flags, or from standard input, one \
            per line. A tab inside an option splits it into the value and a dimmed \
            description shown beneath it.

            Prints the chosen value. With --multiple, prints one per line.

            Examples:
              prettyprompt choose "Deploy where?" -o staging -o production
              git branch --format='%(refname:short)' | prettyprompt choose "Check out?"
            """)

    @Argument(help: "The question.")
    var title: String

    @Option(
        name: [.short, .customLong("option")],
        help: ArgumentHelp("An option. Repeat for each one.", valueName: "text"))
    var options: [String] = []

    @Flag(name: .long, help: "Allow more than one selection.")
    var multiple = false

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Start with this option selected. Repeat with --multiple.", valueName: "value"))
    var select: [String] = []

    @Option(
        name: .long,
        help: ArgumentHelp(
            "With --multiple, the most that can be selected.", valueName: "n"))
    var limit: Int?

    @Flag(name: .long, help: "Print the 0-based position instead of the value.")
    var index = false

    @Flag(name: .long, help: "Always show the filter field, however short the list.")
    var filter = false

    @OptionGroup var presentation: PresentationOptions

    func run() throws {
        let rawOptions = options.isEmpty ? StandardInput.lines() : options
        guard !rawOptions.isEmpty else { throw PromptError.noOptions }

        let choices = rawOptions.map(ChoiceOption.init(rawValue:))
        var preselected = Set<Int>()
        for wanted in select {
            guard let position = choices.firstIndex(where: { $0.value == wanted }) else {
                throw PromptError.unknownDefault(value: wanted)
            }
            preselected.insert(position)
        }
        // A single-select list can only start on one row; the last --select wins
        // rather than silently highlighting several.
        if !multiple, preselected.count > 1, let last = preselected.max() {
            preselected = [last]
        }
        if let limit, limit < 1 {
            throw ValidationError("--limit must be at least 1.")
        }

        let kind = PromptKind.choose(
            ChooseSpec(
                options: choices,
                allowsMultiple: multiple,
                preselected: preselected,
                limit: multiple ? limit : nil,
                forceFilter: filter))
        emit(
            try presentation.makeSpec(title: title, kind: kind),
            json: presentation.json, useIndexes: index)
    }
}

// ---- input ----

struct InputCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "input",
        abstract: "Ask for a line of text.",
        discussion: """
            Prints what was typed. With --password the field is masked and the value \
            never appears in any error message.

            Examples:
              name=$(prettyprompt input "What should I call the branch?")
              token=$(prettyprompt input "API token" --password)
            """)

    @Argument(help: "The question.")
    var title: String

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Greyed-out hint shown in the empty field.", valueName: "text"))
    var placeholder: String?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Pre-fill the field with this.", valueName: "text"))
    var value: String?

    @Flag(name: [.customShort("p"), .customLong("password")], help: "Mask what is typed.")
    var password = false

    @Flag(name: .long, help: "A resizable text area. Enter adds a line, ⌘↩ submits.")
    var multiline = false

    @Flag(name: .long, help: "Refuse to submit an empty answer.")
    var required = false

    @OptionGroup var presentation: PresentationOptions

    func run() throws {
        if password && multiline {
            throw ValidationError("--password and --multiline cannot be combined.")
        }
        let kind = PromptKind.input(
            InputSpec(
                placeholder: placeholder,
                initialValue: value ?? "",
                secure: password,
                multiline: multiline,
                requiresValue: required))
        emit(try presentation.makeSpec(title: title, kind: kind), json: presentation.json)
    }
}

// ---- confirm ----

struct ConfirmCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "confirm",
        abstract: "Ask a yes/no question.",
        discussion: """
            Exits 0 for yes and 1 for no, so it drops straight into an if.

            Examples:
              if prettyprompt confirm "Deploy to production?" --destructive; then
                ./deploy.sh
              fi
            """)

    @Argument(help: "The question.")
    var title: String

    @Option(
        name: .customLong("yes"),
        help: ArgumentHelp(
            "Label for the affirmative button.", valueName: "label"))
    var affirmative = "OK"

    @Option(
        name: .customLong("no"),
        help: ArgumentHelp(
            "Label for the negative button.", valueName: "label"))
    var negative = "Cancel"

    @Flag(name: .customLong("default-no"), help: "Focus the negative button, so Enter says no.")
    var defaultNo = false

    @Flag(name: .long, help: "Paint the affirmative button as dangerous.")
    var destructive = false

    @OptionGroup var presentation: PresentationOptions

    func run() throws {
        let kind = PromptKind.confirm(
            ConfirmSpec(
                affirmative: affirmative,
                negative: negative,
                defaultsToYes: !defaultNo,
                destructive: destructive))
        emit(try presentation.makeSpec(title: title, kind: kind), json: presentation.json)
    }
}

// ---- alert ----

struct AlertCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "alert",
        abstract: "Say something and wait to be acknowledged.",
        discussion: """
            No question, one button. For the moment a long script needs you to look up.

            Examples:
              make build || prettyprompt alert "Build failed" --icon ⚠️ --sound
            """)

    @Argument(help: "The headline.")
    var title: String

    @Option(
        name: [.short, .long],
        help: ArgumentHelp(
            "Label for the dismiss button.", valueName: "label"))
    var button = "OK"

    @OptionGroup var presentation: PresentationOptions

    func run() throws {
        emit(
            try presentation.makeSpec(title: title, kind: .alert(buttonLabel: button)),
            json: presentation.json)
    }
}
