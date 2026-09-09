// Renders the theme gallery. Run with `mise run gallery`.

import Foundation
import PrettyPromptKit

let destination = URL(
    fileURLWithPath: CommandLine.arguments.count > 1
        ? CommandLine.arguments[1]
        : "docs/gallery")

do {
    try MainActor.assumeIsolated { try Gallery.render(into: destination) }
    print("✓ gallery written to \(destination.path)")
} catch {
    FileHandle.standardError.write(Data("gallery: \(error)\n".utf8))
    exit(1)
}
