// When a prompt makes noise, and which noise.
//
// The interesting rule is that sound is not simply off by default: a
// destructive confirm is audible unless silenced, because the whole point of
// --destructive is that it should be hard to answer without noticing.

import ArgumentParser
import XCTest

@testable import PrettyPromptKit

final class SoundCatalogueTests: XCTestCase {
    func testEveryThemeSoundIsRealAndSpelledRight() {
        for theme in BuiltInThemes.all {
            guard let sound = theme.style.sound else { continue }
            XCTAssertTrue(
                Sound.exists(sound), "\(theme.name) names a sound that does not exist: \(sound)")
            XCTAssertEqual(Sound.canonical(sound), sound, "\(theme.name)'s sound is miscapitalised")
        }
    }

    func testFallbackIsARealSound() {
        XCTAssertTrue(Sound.exists(Sound.fallback))
    }

    func testLookupIsCaseInsensitiveButReturnsCanonicalSpelling() {
        XCTAssertEqual(Sound.canonical("basso"), "Basso")
        XCTAssertEqual(Sound.canonical("SUBMARINE"), "Submarine")
        XCTAssertNil(Sound.canonical("Airhorn"))
    }

    /// The themes with a voice should not all share one.
    func testThemeSoundsAreVaried() {
        let voices = Set(BuiltInThemes.all.compactMap(\.style.sound))
        XCTAssertGreaterThan(voices.count, 4)
    }
}

final class SoundResolutionTests: XCTestCase {
    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("prettyprompt-sound-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
        setenv("XDG_CONFIG_HOME", scratch.path, 1)
    }

    override func tearDownWithError() throws {
        unsetenv("XDG_CONFIG_HOME")
        try? FileManager.default.removeItem(at: scratch)
    }

    private func writeConfig(_ json: String) throws {
        let directory = scratch.appendingPathComponent("prettyprompt")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: directory.appendingPathComponent("config.json"))
    }

    private func sound(_ arguments: [String], kind: PromptKind) throws -> String? {
        try PresentationOptions.parse(arguments).makeSpec(title: "T", kind: kind).sound
    }

    private static let destructive = PromptKind.confirm(
        ConfirmSpec(affirmative: "Drop it", negative: "Cancel", destructive: true))
    private static let ordinary = PromptKind.confirm(ConfirmSpec())
    private static let alert = PromptKind.alert(buttonLabel: "OK")

    func testOrdinaryPromptsAreSilent() throws {
        XCTAssertNil(try sound([], kind: Self.ordinary))
        XCTAssertNil(try sound([], kind: Self.alert))
    }

    /// The rule worth having a test for.
    func testDestructiveConfirmsAreAudibleByDefault() throws {
        XCTAssertEqual(
            try sound([], kind: Self.destructive), BuiltInThemes.auto.style.sound ?? Sound.fallback)
    }

    func testDestructiveConfirmUsesTheThemesVoice() throws {
        XCTAssertEqual(
            try sound(["--theme", "danger"], kind: Self.destructive),
            BuiltInThemes.danger.style.sound)
    }

    func testNoSoundSilencesEvenADestructiveConfirm() throws {
        XCTAssertNil(try sound(["--no-sound"], kind: Self.destructive))
        XCTAssertNil(try sound(["--no-sound", "--theme", "doom"], kind: Self.destructive))
    }

    func testSoundFlagTurnsOnAnOrdinaryPrompt() throws {
        XCTAssertEqual(
            try sound(["--sound", "--theme", "hotdog"], kind: Self.alert),
            BuiltInThemes.hotdog.style.sound)
    }

    func testThemeWithoutAVoiceFallsBackToTheNeutralChime() throws {
        XCTAssertNil(BuiltInThemes.auto.style.sound)
        XCTAssertEqual(try sound(["--sound", "--theme", "auto"], kind: Self.alert), Sound.fallback)
    }

    func testSoundNameImpliesSoundAndOverridesTheTheme() throws {
        XCTAssertEqual(
            try sound(["--sound-name", "Frog", "--theme", "doom"], kind: Self.alert), "Frog")
    }

    func testSoundNameIsCaseInsensitive() throws {
        XCTAssertEqual(try sound(["--sound-name", "frog"], kind: Self.alert), "Frog")
    }

    /// --no-sound still wins, so a config or a habit cannot make a script noisy.
    func testExplicitSilenceBeatsAnExplicitName() throws {
        XCTAssertNil(try sound(["--sound-name", "Frog", "--no-sound"], kind: Self.alert))
    }

    func testUnknownSoundIsRejectedBeforeAWindowOpens() throws {
        XCTAssertThrowsError(try sound(["--sound-name", "Airhorn"], kind: Self.alert))
    }

    func testConfigCanTurnSoundOnEverywhere() throws {
        try writeConfig("{\"sound\":true}")
        XCTAssertEqual(
            try sound(["--theme", "nord"], kind: Self.alert), BuiltInThemes.nord.style.sound)
    }

    func testConfigSoundNameOverridesEveryThemesVoice() throws {
        try writeConfig("{\"sound\":true,\"soundName\":\"Hero\"}")
        XCTAssertEqual(try sound(["--theme", "doom"], kind: Self.alert), "Hero")
        XCTAssertEqual(
            try sound(["--sound-name", "Frog", "--theme", "doom"], kind: Self.alert), "Frog")
    }

    func testFlagBeatsConfig() throws {
        try writeConfig("{\"sound\":true}")
        XCTAssertNil(try sound(["--no-sound"], kind: Self.alert))
    }
}
