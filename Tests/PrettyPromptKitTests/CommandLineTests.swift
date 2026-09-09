// Parsing the command line.
//
// ArgumentParser validates its own configuration lazily, at the moment a
// command is parsed — a duplicated short flag between PresentationOptions and a
// subcommand compiles perfectly and then fails at runtime for the user. Parsing
// every subcommand here is what turns that into a test failure instead.

import ArgumentParser
import XCTest

@testable import PrettyPromptKit

final class CommandLineTests: XCTestCase {
    /// Points config lookups at a scratch directory so these never read, or
    /// depend on, whatever is in the developer's real ~/.config.
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("prettyprompt-cli-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        setenv("XDG_CONFIG_HOME", scratch.path, 1)
    }

    override func tearDownWithError() throws {
        unsetenv("XDG_CONFIG_HOME")
        try? FileManager.default.removeItem(at: scratch)
    }

    private func parse(_ arguments: [String]) throws -> ParsableCommand {
        try RootCommand.parseAsRoot(arguments)
    }

    // ---- Configuration validity ----

    /// Every subcommand, with every shared flag, in one go. This is the test
    /// that catches two options claiming the same short letter.
    func testEverySubcommandParsesWithEverySharedFlag() throws {
        let shared = [
            "--message", "m", "--icon", "star", "--theme", "doom",
            "--width", "500", "--timeout", "5", "--on-timeout", "accept",
            "--insist", "--sound", "--json", "--screen", "focused",
        ]
        let commands = [
            ["choose", "Pick", "--option", "a"],
            ["input", "Name"],
            ["confirm", "Sure?"],
            ["alert", "Look"],
        ]
        for command in commands {
            XCTAssertNoThrow(try parse(command + shared), command.joined(separator: " "))
        }
    }

    func testShortFlagsParse() throws {
        XCTAssertNoThrow(
            try parse(["choose", "Pick", "-o", "a", "-o", "b", "-m", "hi", "-t", "3"]))
        XCTAssertNoThrow(try parse(["input", "Token", "-p"]))
        XCTAssertNoThrow(try parse(["alert", "Done", "-b", "Fine"]))
    }

    /// `--help` is the documentation most people will actually read, so it has
    /// to exist and be more than a flag dump for every subcommand.
    func testEverySubcommandHasHelpWithAWorkedExample() {
        let commands: [(String, ParsableCommand.Type)] = [
            ("choose", ChooseCommand.self), ("input", InputCommand.self),
            ("confirm", ConfirmCommand.self), ("alert", AlertCommand.self),
            ("themes", ThemesCommand.self),
        ]
        for (name, command) in commands {
            let help = command.helpMessage(columns: 100)
            XCTAssertTrue(help.contains("OVERVIEW:"), "\(name) has no abstract")
            XCTAssertTrue(help.contains("prettyprompt "), "\(name) help has no example invocation")
        }
    }

    /// The root help carries the exit-code table — the contract a script author
    /// needs before writing anything.
    func testRootHelpDocumentsTheExitCodes() {
        let help = RootCommand.helpMessage(columns: 100)
        for code in ["0", "1", "2", "124", "130"] {
            XCTAssertTrue(help.contains(code), "root help does not mention exit code \(code)")
        }
    }

    // ---- Argument handling ----

    func testChooseRequiresOptionsFromSomewhere() throws {
        var command = try XCTUnwrap(parse(["choose", "Pick"]) as? ChooseCommand)
        // stdin is not a pipe under the test runner, so there is nothing to
        // fall back to and the user gets told how to supply options.
        XCTAssertThrowsError(try command.run()) { error in
            guard case PromptError.noOptions = error else {
                return XCTFail("expected noOptions, got \(error)")
            }
        }
    }

    func testPreselectingAnUnknownValueIsRejected() throws {
        var command = try XCTUnwrap(
            parse(["choose", "Pick", "-o", "a", "--select", "z"]) as? ChooseCommand)
        XCTAssertThrowsError(try command.run()) { error in
            guard case PromptError.unknownDefault = error else {
                return XCTFail("expected unknownDefault, got \(error)")
            }
        }
    }

    func testPasswordAndMultilineAreMutuallyExclusive() throws {
        var command = try XCTUnwrap(parse(["input", "T", "-p", "--multiline"]) as? InputCommand)
        XCTAssertThrowsError(try command.run())
    }

    // ---- Spec construction ----

    private func presentation(_ arguments: [String]) throws -> PresentationOptions {
        try PresentationOptions.parse(arguments)
    }

    func testDefaultsWhenNothingIsGiven() throws {
        let spec = try presentation([]).makeSpec(title: "T", kind: .alert(buttonLabel: "OK"))
        XCTAssertEqual(spec.theme.name, BuiltInThemes.defaultName)
        XCTAssertEqual(spec.width, CGFloat(PresentationOptions.defaultWidth))
        XCTAssertEqual(spec.screen, .mouse)
        XCTAssertNil(spec.timeout)
        XCTAssertFalse(spec.insist)
    }

    func testConfigFileSuppliesDefaults() throws {
        let directory = scratch.appendingPathComponent("prettyprompt")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{\"theme\":\"doom\",\"width\":520,\"timeout\":9}".utf8)
            .write(to: directory.appendingPathComponent("config.json"))

        let spec = try presentation([]).makeSpec(title: "T", kind: .alert(buttonLabel: "OK"))
        XCTAssertEqual(spec.theme.name, "doom")
        XCTAssertEqual(spec.width, 520)
        XCTAssertEqual(spec.timeout, 9)
    }

    func testCommandLineBeatsConfigFile() throws {
        let directory = scratch.appendingPathComponent("prettyprompt")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{\"theme\":\"doom\",\"width\":520}".utf8)
            .write(to: directory.appendingPathComponent("config.json"))

        let spec = try presentation(["--theme", "nord", "--width", "600"])
            .makeSpec(title: "T", kind: .alert(buttonLabel: "OK"))
        XCTAssertEqual(spec.theme.name, "nord")
        XCTAssertEqual(spec.width, 600)
    }

    func testUnknownThemeIsRejected() throws {
        XCTAssertThrowsError(
            try presentation(["--theme", "chartreuse"])
                .makeSpec(title: "T", kind: .alert(buttonLabel: "OK")))
    }

    func testImplausibleWidthsAreRejected() throws {
        XCTAssertThrowsError(
            try presentation(["--width", "40"])
                .makeSpec(title: "T", kind: .alert(buttonLabel: "OK")))
        XCTAssertThrowsError(
            try presentation(["--width", "9000"])
                .makeSpec(title: "T", kind: .alert(buttonLabel: "OK")))
    }

    func testNonPositiveTimeoutIsRejected() throws {
        XCTAssertThrowsError(
            try presentation(["--timeout", "0"])
                .makeSpec(title: "T", kind: .alert(buttonLabel: "OK")))
    }

    func testBadScreenIsRejected() throws {
        XCTAssertThrowsError(
            try presentation(["--screen", "sideways"])
                .makeSpec(title: "T", kind: .alert(buttonLabel: "OK")))
    }
}
