// Theme resolution, including the user-supplied JSON path. A theme that fails
// to load has to say so — falling back to a default would leave someone
// wondering why their file is ignored.

import XCTest

@testable import PrettyPromptKit

final class ThemeLoaderTests: XCTestCase {
    private var themesDirectory: URL!

    override func setUpWithError() throws {
        themesDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("prettyprompt-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: themesDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: themesDirectory)
    }

    private func writeTheme(named name: String, from source: Theme) throws {
        let encoder = JSONEncoder()
        try encoder.encode(source).write(to: themesDirectory.appendingPathComponent("\(name).json"))
    }

    func testResolvesBuiltIn() throws {
        XCTAssertEqual(
            try ThemeLoader.resolve("nord", themesDirectory: themesDirectory).name, "nord")
    }

    func testResolvesCustomThemeFromDisk() throws {
        try writeTheme(named: "midnight", from: BuiltInThemes.nord)
        let theme = try ThemeLoader.resolve("midnight", themesDirectory: themesDirectory)
        XCTAssertEqual(theme.dark, BuiltInThemes.nord.dark)
    }

    /// The file name is what the user types, so it wins over a stale "name"
    /// left inside a copied-and-edited file.
    func testFileNameWinsOverEmbeddedName() throws {
        try writeTheme(named: "midnight", from: BuiltInThemes.nord)
        XCTAssertEqual(
            try ThemeLoader.resolve("midnight", themesDirectory: themesDirectory).name,
            "midnight")
    }

    func testBuiltInsCannotBeShadowed() throws {
        try writeTheme(named: "doom", from: BuiltInThemes.hotdog)
        let theme = try ThemeLoader.resolve("doom", themesDirectory: themesDirectory)
        XCTAssertEqual(theme.dark, BuiltInThemes.doom.dark)
        XCTAssertFalse(ThemeLoader.customNames(in: themesDirectory).contains("doom"))
    }

    func testUnknownThemeListsWhatIsAvailable() throws {
        try writeTheme(named: "midnight", from: BuiltInThemes.nord)
        XCTAssertThrowsError(try ThemeLoader.resolve("nope", themesDirectory: themesDirectory)) {
            error in
            guard case let PromptError.unknownTheme(name, available) = error else {
                return XCTFail("expected unknownTheme, got \(error)")
            }
            XCTAssertEqual(name, "nope")
            XCTAssertTrue(available.contains("doom"))
            XCTAssertTrue(available.contains("midnight"))
        }
    }

    func testMalformedThemeIsReportedNotIgnored() throws {
        try Data("{ not json".utf8)
            .write(to: themesDirectory.appendingPathComponent("broken.json"))
        XCTAssertThrowsError(try ThemeLoader.resolve("broken", themesDirectory: themesDirectory)) {
            error in
            guard case PromptError.badTheme = error else {
                return XCTFail("expected badTheme, got \(error)")
            }
        }
    }

    func testEveryBuiltInSurvivesAJSONRoundTrip() throws {
        // `themes --export` prints these for users to edit, so they have to
        // decode back into themselves.
        for theme in BuiltInThemes.all {
            let data = try JSONEncoder().encode(theme)
            XCTAssertEqual(try JSONDecoder().decode(Theme.self, from: data), theme, theme.name)
        }
    }
}

final class ConfigTests: XCTestCase {
    func testMissingConfigIsEmptyNotAnError() throws {
        let missing = URL(fileURLWithPath: "/nonexistent/prettyprompt/config.json")
        XCTAssertEqual(try Config.load(from: missing), .empty)
    }

    func testMalformedConfigIsReported() throws {
        let file = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pp-config-\(UUID().uuidString).json")
        try Data("{ \"theme\": 12 }".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        XCTAssertThrowsError(try Config.load(from: file)) { error in
            guard case PromptError.badConfig = error else {
                return XCTFail("expected badConfig, got \(error)")
            }
        }
    }

    func testReadsKnownKeys() throws {
        let file = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pp-config-\(UUID().uuidString).json")
        try Data("{\"theme\":\"doom\",\"width\":520,\"sound\":true}".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let config = try Config.load(from: file)
        XCTAssertEqual(config.theme, "doom")
        XCTAssertEqual(config.width, 520)
        XCTAssertEqual(config.sound, true)
        XCTAssertNil(config.timeout)
    }
}
