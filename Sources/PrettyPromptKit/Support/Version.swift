// Version information, read from the app bundle.
//
// Swift has no ldflags, so build-app.sh writes the version, commit and build
// date into Info.plist and this reads them back. A `swift run` from a checkout
// has no bundle and reports "dev", which is also the signal that this is not a
// release build.

import Foundation

enum Version {
    static let developmentMarker = "dev"

    static var number: String {
        value(for: "CFBundleShortVersionString") ?? developmentMarker
    }

    static var commit: String? { value(for: "PPGitCommit") }
    static var buildDate: String? { value(for: "PPBuildDate") }

    /// `prettyprompt v1.2.3 (abc1234, 2026-01-15T10:30:00Z)` — the string
    /// `--version` prints.
    static var full: String {
        // A release reads "v1.2.3"; a checkout build reads plain "dev", because
        // "vdev" is nonsense.
        var text = number == developmentMarker ? "prettyprompt dev" : "prettyprompt v\(number)"
        let details = [commit, buildDate].compactMap { $0 }
        if !details.isEmpty {
            text += " (\(details.joined(separator: ", ")))"
        }
        return text
    }

    private static func value(for key: String) -> String? {
        guard let raw = Bundle.main.infoDictionary?[key] as? String,
            !raw.isEmpty,
            // build-app.sh writes these placeholders when there is no tag and
            // no git; they are worse than saying nothing.
            raw != "0.0.0", raw != "unknown"
        else { return nil }
        return raw
    }
}
