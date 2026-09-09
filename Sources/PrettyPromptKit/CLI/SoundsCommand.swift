// `prettyprompt sounds` — what a prompt can sound like, and a way to hear it.
//
// Listing goes to stdout as plain text so it can be piped into grep. Previewing
// plays the sound and waits, because a command that exits before the speaker
// moves is not a preview.

import ArgumentParser
import Foundation

struct SoundsCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sounds",
        abstract: "List the sounds a prompt can play, or hear one.",
        discussion: """
            These come from macOS itself rather than being bundled, so they are \
            the fourteen every Mac already has. Each theme picks the one that \
            suits it; --sound-name overrides that.

            A destructive confirm plays its theme's sound unless you pass \
            --no-sound, on the grounds that it should be hard to answer one \
            without noticing.

              prettyprompt sounds
              prettyprompt sounds Basso
              prettyprompt sounds --all
              prettyprompt confirm "Ship it?" --theme danger --destructive
            """)

    @Argument(help: ArgumentHelp("Play this sound.", valueName: "name"))
    var name: String?

    @Flag(name: .long, help: "Play every sound in turn.")
    var all = false

    @Flag(name: .long, help: "Print the list as JSON.")
    var json = false

    func run() throws {
        if all {
            for sound in Sound.available {
                print(sound)
                Sound.playAndWait(sound)
            }
            return
        }
        if let name {
            guard let canonical = Sound.canonical(name) else {
                throw PromptError.unknownSound(name: name, available: Sound.available)
            }
            print(canonical)
            Sound.playAndWait(canonical)
            return
        }
        try printList()
    }

    /// Each sound, annotated with the themes that use it, so the list answers
    /// "what does --theme doom sound like?" without a second lookup.
    private func printList() throws {
        var usedBy: [String: [String]] = [:]
        for theme in BuiltInThemes.all {
            guard let sound = theme.style.sound else { continue }
            usedBy[sound, default: []].append(theme.name)
        }

        guard !json else {
            let rows = Sound.available.map {
                ["name": $0, "themes": usedBy[$0] ?? []] as [String: Any]
            }
            let data = try JSONSerialization.data(
                withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
            print(String(decoding: data, as: UTF8.self))
            return
        }

        let width = Sound.available.map(\.count).max() ?? 10
        for sound in Sound.available {
            let note =
                usedBy[sound]?.joined(separator: ", ")
                ?? (sound == Sound.fallback ? "default" : "")
            guard !note.isEmpty else {
                print("  \(sound)")
                continue
            }
            print("  \(sound.padding(toLength: width, withPad: " ", startingAt: 0))  \(note)")
        }
    }
}
