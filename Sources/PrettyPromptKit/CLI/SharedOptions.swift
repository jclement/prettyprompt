// Flags every prompt understands, and the glue that turns them into a
// PromptSpec.
//
// These live in one place because the whole point of prettyprompt is that
// --theme, --timeout and --json mean the same thing whichever prompt you asked
// for. Precedence is always: command line > config file > built-in default.

import ArgumentParser
import CoreGraphics
import Foundation

extension TimeoutBehaviour: ExpressibleByArgument {}

/// Options shared by `choose`, `input`, `confirm` and `alert`.
struct PresentationOptions: ParsableArguments {
    @Option(
        name: [.short, .long],
        help: ArgumentHelp(
            "A supporting line shown under the title.", valueName: "text"))
    var message: String?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "An emoji, or an SF Symbol name like exclamationmark.triangle.fill.",
            valueName: "icon"))
    var icon: String?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Theme name. See `prettyprompt themes`.", valueName: "name"))
    var theme: String?

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Panel width in points (default 460).", valueName: "points"))
    var width: Double?

    @Option(
        name: [.short, .long],
        help: ArgumentHelp(
            "Give up after this many seconds.", valueName: "seconds"))
    var timeout: Double?

    @Option(
        name: .customLong("on-timeout"),
        help: ArgumentHelp(
            "What a timeout does: cancel (exit 124) or accept the current answer.",
            valueName: "cancel|accept"))
    var onTimeout: TimeoutBehaviour = .cancel

    @Flag(name: .long, help: "Remove every way out. Esc will not dismiss the prompt.")
    var insist = false

    @Flag(name: .long, help: "Play the system alert sound when the prompt appears.")
    var sound = false

    @Flag(name: .long, help: "Print a JSON object instead of a bare answer.")
    var json = false

    @Option(
        name: .long,
        help: ArgumentHelp(
            "Which display to open on: mouse (default), focused, or a 0-based index.",
            valueName: "where"))
    var screen: String?

    /// Fills in the parts of a PromptSpec that don't depend on the prompt kind.
    ///
    /// Reads the config file for anything not given on the command line, so a
    /// caller only has to construct the `kind`.
    func makeSpec(title: String, kind: PromptKind) throws -> PromptSpec {
        let config = try Config.load()

        let themeName = theme ?? config.theme ?? BuiltInThemes.defaultName
        let resolvedTheme = try ThemeLoader.resolve(themeName)

        let screenArgument = screen ?? config.screen
        let resolvedScreen: ScreenChoice
        if let screenArgument {
            guard let parsed = ScreenChoice(argument: screenArgument) else {
                throw ValidationError(
                    "--screen must be \"mouse\", \"focused\", or a display index like 0.")
            }
            resolvedScreen = parsed
        } else {
            resolvedScreen = .mouse
        }

        let resolvedTimeout = timeout ?? config.timeout
        if let resolvedTimeout, resolvedTimeout <= 0 {
            throw ValidationError("--timeout must be greater than zero.")
        }

        let resolvedWidth = width ?? config.width ?? Self.defaultWidth
        guard resolvedWidth >= Self.minimumWidth, resolvedWidth <= Self.maximumWidth else {
            throw ValidationError(
                "--width must be between \(Int(Self.minimumWidth)) and \(Int(Self.maximumWidth)).")
        }

        return PromptSpec(
            title: title,
            message: message,
            icon: icon,
            kind: kind,
            theme: resolvedTheme,
            width: CGFloat(resolvedWidth),
            timeout: resolvedTimeout,
            timeoutBehaviour: onTimeout,
            insist: insist,
            sound: sound || (config.sound ?? false),
            screen: resolvedScreen)
    }

    /// Wide enough for a sentence at the default type size without feeling like
    /// a system alert; narrow enough to read as a prompt rather than a window.
    static let defaultWidth: Double = 460
    static let minimumWidth: Double = 260
    static let maximumWidth: Double = 1200
}
