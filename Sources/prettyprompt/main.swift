// The executable. Everything real lives in PrettyPromptKit so that it can be
// tested and rendered offscreen; this is only the entry point.
//
// ArgumentParser's own `main()` would exit 64 on a bad flag and swallow our
// PromptError messages, so the dispatch is written out here to keep the exit
// codes matching PrettyPromptKit's PromptExit — the contract shell scripts
// depend on.

import ArgumentParser
import Foundation
import PrettyPromptKit

do {
    var command = try RootCommand.parseAsRoot()
    try command.run()
    exit(PromptExit.success)
} catch let error as PromptError {
    FileHandle.standardError.write(Data(("prettyprompt: " + error.message + "\n").utf8))
    exit(error.exitCode)
} catch {
    // --help and --version arrive here as "clean" exits carrying their output.
    if RootCommand.exitCode(for: error) == .success {
        print(RootCommand.message(for: error))
        exit(PromptExit.success)
    }
    FileHandle.standardError.write(Data((RootCommand.fullMessage(for: error) + "\n").utf8))
    exit(PromptExit.usage)
}
