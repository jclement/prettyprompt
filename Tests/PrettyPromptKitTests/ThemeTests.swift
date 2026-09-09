// Themes are data, and data that renders wrong is hard to notice. These cover
// the parts that would silently produce an unreadable prompt: colour parsing,
// the opacity helper (which used to overwrite alpha instead of scaling it, and
// turned light themes' buttons into dark slabs), and appearance selection.

import XCTest

@testable import PrettyPromptKit

final class ThemeColorTests: XCTestCase {
    func testParsesSixDigitHex() {
        let color = ThemeColor(hex: "#3366CC")
        XCTAssertEqual(color?.red ?? 0, 0.2, accuracy: 0.01)
        XCTAssertEqual(color?.green ?? 0, 0.4, accuracy: 0.01)
        XCTAssertEqual(color?.blue ?? 0, 0.8, accuracy: 0.01)
        XCTAssertEqual(color?.alpha, 1)
    }

    func testParsesEightDigitHexAsAlpha() {
        let color = ThemeColor(hex: "#00000080")
        XCTAssertEqual(color?.alpha ?? 0, 0.5, accuracy: 0.01)
    }

    func testExpandsShorthand() {
        XCTAssertEqual(ThemeColor(hex: "#f0a"), ThemeColor(hex: "#FF00AA"))
    }

    func testAcceptsHexWithoutHash() {
        XCTAssertEqual(ThemeColor(hex: "FF00AA"), ThemeColor(hex: "#FF00AA"))
    }

    func testRejectsNonsense() {
        XCTAssertNil(ThemeColor(hex: "#GGGGGG"))
        XCTAssertNil(ThemeColor(hex: "#12345"))
        XCTAssertNil(ThemeColor(hex: "rebeccapurple"))
        XCTAssertNil(ThemeColor(hex: ""))
    }

    func testHexStringRoundTrips() {
        XCTAssertEqual(ThemeColor(hex: "#3366CC")?.hexString, "#3366CC")
        XCTAssertEqual(ThemeColor(hex: "#33660080")?.hexString, "#33660080")
    }

    /// The bug this exists for: `surface` in a light theme is 5% black. Setting
    /// its alpha to 0.55 makes a dark grey slab; scaling it keeps a wash.
    func testOpacityScalesExistingAlphaRatherThanReplacingIt() {
        let subtleOverlay = ThemeColor(hex: "#0000000D")!
        XCTAssertEqual(subtleOverlay.opacity(0.5).alpha, subtleOverlay.alpha * 0.5, accuracy: 0.001)
        XCTAssertLessThan(subtleOverlay.opacity(0.55).alpha, 0.05)
    }

    func testDecodesFromBareJSONString() throws {
        let decoded = try JSONDecoder().decode(ThemeColor.self, from: Data("\"#FF00AA\"".utf8))
        XCTAssertEqual(decoded, ThemeColor(hex: "#FF00AA"))
    }

    func testDecodingReportsBadColour() {
        XCTAssertThrowsError(try JSONDecoder().decode(ThemeColor.self, from: Data("\"puce\"".utf8)))
    }
}

final class ThemeTests: XCTestCase {
    func testEveryBuiltInThemeHasAUniqueName() {
        let names = BuiltInThemes.all.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testDefaultThemeExists() {
        XCTAssertNotNil(BuiltInThemes.named(BuiltInThemes.defaultName))
    }

    func testLookupIsCaseInsensitive() {
        XCTAssertEqual(BuiltInThemes.named("DOOM")?.name, "doom")
    }

    func testSystemThemeFollowsAppearance() {
        XCTAssertEqual(BuiltInThemes.auto.palette(systemIsDark: true), BuiltInThemes.auto.dark)
        XCTAssertEqual(BuiltInThemes.auto.palette(systemIsDark: false), BuiltInThemes.auto.light)
    }

    func testPinnedThemesIgnoreAppearance() {
        XCTAssertEqual(BuiltInThemes.dark.palette(systemIsDark: false), BuiltInThemes.dark.dark)
        XCTAssertEqual(BuiltInThemes.light.palette(systemIsDark: true), BuiltInThemes.light.light)
    }

    /// Drives which NSAppearance the panel adopts. A light theme reporting
    /// "dark" gets a dark frosted backdrop behind a pale panel.
    func testBackgroundLuminanceClassification() {
        XCTAssertTrue(BuiltInThemes.doom.dark.isDarkBackground)
        XCTAssertTrue(BuiltInThemes.danger.dark.isDarkBackground)
        XCTAssertFalse(BuiltInThemes.hotdog.dark.isDarkBackground)
        XCTAssertFalse(BuiltInThemes.paper.dark.isDarkBackground)
    }

    func testOnlyDangerWearsHazardStripes() {
        let striped = BuiltInThemes.all.filter { $0.style.hazardStripes }.map(\.name)
        XCTAssertEqual(striped, ["danger"])
    }
}
