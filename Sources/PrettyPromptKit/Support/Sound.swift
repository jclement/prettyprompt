// Making noise.
//
// Sounds come from /System/Library/Sounds rather than being embedded in the
// bundle: they are the fourteen every Mac user already knows, they cost nothing
// to ship, and NSSound finds them by name with no file handling here. A theme
// picks one that matches its character, so `--theme danger --sound` thuds and
// `--theme hotdog --sound` honks without the caller choosing.

import AppKit

enum Sound {
    /// The sounds macOS ships, in the order `prettyprompt sounds` prints them.
    /// Hard-coded rather than globbed so the list is stable and testable, and
    /// so a name can be validated before a window opens.
    static let available = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]

    /// Played when a prompt asks for sound and neither the caller nor the theme
    /// named one. Neutral on purpose — the themes with something to say say it.
    static let fallback = "Ping"

    static func exists(_ name: String) -> Bool {
        available.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Canonical capitalisation for a name the user typed, or nil if unknown.
    static func canonical(_ name: String) -> String? {
        available.first { $0.caseInsensitiveCompare(name) == .orderedSame }
    }

    /// Plays asynchronously and returns immediately. The prompt window outlives
    /// the sound, so there is nothing to wait for.
    static func play(_ name: String) {
        NSSound(named: NSSound.Name(name))?.play()
    }

    /// Plays and blocks until it finishes — only for `prettyprompt sounds`,
    /// which would otherwise exit before anything was audible.
    static func playAndWait(_ name: String) {
        guard let sound = NSSound(named: NSSound.Name(name)) else { return }
        sound.play()
        // NSSound.duration is unreliable for some system sounds; cap the wait so
        // a preview can never hang the command.
        let limit = min(max(sound.duration, 0.2), 3.0)
        RunLoop.current.run(until: Date().addingTimeInterval(limit))
    }
}
