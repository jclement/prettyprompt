// Block parsing for prompt messages. The inline styling is AttributedString's
// job; what is worth testing is the structure it cannot express — newlines that
// have to survive, bullets, and fenced code.

import XCTest

@testable import PrettyPromptKit

final class MarkdownTests: XCTestCase {
    func testEachLineIsItsOwnParagraph() {
        // Real markdown would reflow these into one paragraph. Someone who put
        // a newline in --message meant it.
        XCTAssertEqual(
            Markdown.blocks(from: "one\ntwo"),
            [.paragraph("one"), .paragraph("two")])
    }

    func testBulletMarkersAreRecognised() {
        XCTAssertEqual(
            Markdown.blocks(from: "- a\n* b\n• c"),
            [.bullet("a"), .bullet("b"), .bullet("c")])
    }

    func testHyphenatedWordIsNotABullet() {
        XCTAssertEqual(Markdown.blocks(from: "well-known"), [.paragraph("well-known")])
    }

    func testBlankLineBecomesOneGap() {
        XCTAssertEqual(
            Markdown.blocks(from: "a\n\n\n\nb"),
            [.paragraph("a"), .gap, .paragraph("b")])
    }

    func testLeadingBlankLinesAreDropped() {
        XCTAssertEqual(Markdown.blocks(from: "\n\na"), [.paragraph("a")])
    }

    func testFencedCodeKeepsItsNewlines() {
        XCTAssertEqual(
            Markdown.blocks(from: "```\nswift build\nswift test\n```"),
            [.code("swift build\nswift test")])
    }

    func testUnclosedFenceStillRenders() {
        XCTAssertEqual(Markdown.blocks(from: "```\nswift build"), [.code("swift build")])
    }

    func testEmptySourceProducesNothing() {
        XCTAssertEqual(Markdown.blocks(from: ""), [])
    }

    func testInlineMarkdownFallsBackToRawTextWhenUnparseable() {
        let context = ThemeContext(palette: BuiltInThemes.auto.dark, style: Style())
        // Whatever happens, the user's words reach the screen.
        XCTAssertFalse(String(Markdown.inline("[unclosed", ui: context).characters).isEmpty)
    }
}
