// The shell contract. Everything here is something a script would break on if
// it changed: what lands on stdout, and what the exit code says.

import XCTest

@testable import PrettyPromptKit

final class ExitCodeTests: XCTestCase {
    func testAnswersSucceed() {
        XCTAssertEqual(PromptOutcome.text("hi").exitCode, 0)
        XCTAssertEqual(PromptOutcome.chosen(values: ["a"], indexes: [0]).exitCode, 0)
        XCTAssertEqual(PromptOutcome.acknowledged.exitCode, 0)
    }

    /// `confirm` spends exit 1 on a real answer, which is why runtime failures
    /// use 70 instead. `if prettyprompt confirm …; then` depends on this.
    func testConfirmUsesZeroAndOne() {
        XCTAssertEqual(PromptOutcome.confirmed(true).exitCode, 0)
        XCTAssertEqual(PromptOutcome.confirmed(false).exitCode, 1)
    }

    func testCancelAndTimeoutAreDistinguishable() {
        XCTAssertEqual(PromptOutcome.cancelled.exitCode, 130)
        XCTAssertEqual(PromptOutcome.timedOut.exitCode, 124)
        XCTAssertNotEqual(PromptExit.cancelled, PromptExit.timedOut)
    }

    func testRuntimeErrorsStayOutOfConfirmsRange() {
        XCTAssertNotEqual(PromptExit.internalError, PromptExit.declined)
        XCTAssertEqual(PromptError.cannotConnectToWindowServer.exitCode, PromptExit.internalError)
        XCTAssertEqual(PromptError.noOptions.exitCode, PromptExit.usage)
    }
}

final class OutcomeWriterTests: XCTestCase {
    private func plain(_ outcome: PromptOutcome, indexes: Bool = false) -> String? {
        OutcomeWriter.render(outcome, json: false, useIndexes: indexes)
    }

    private func json(_ outcome: PromptOutcome, indexes: Bool = false) -> String? {
        OutcomeWriter.render(outcome, json: true, useIndexes: indexes)
    }

    /// `name=$(prettyprompt input …)` must need no trimming or filtering.
    func testPlainTextIsBare() {
        XCTAssertEqual(plain(.text("Jeff Clement")), "Jeff Clement")
    }

    func testMultipleChoicesArePrintedOnePerLine() {
        XCTAssertEqual(plain(.chosen(values: ["a", "b"], indexes: [0, 3])), "a\nb")
    }

    func testIndexModePrintsPositions() {
        XCTAssertEqual(plain(.chosen(values: ["a", "b"], indexes: [0, 3]), indexes: true), "0\n3")
    }

    /// A cancelled prompt must not put anything in a variable the script is
    /// about to use — the exit code is the whole signal.
    func testNothingIsPrintedForNonAnswers() {
        XCTAssertNil(plain(.cancelled))
        XCTAssertNil(plain(.timedOut))
        XCTAssertNil(plain(.confirmed(true)))
        XCTAssertNil(plain(.acknowledged))
    }

    func testJSONAlwaysCarriesStatus() throws {
        for outcome: PromptOutcome in [
            .text("x"), .chosen(values: ["a"], indexes: [0]),
            .confirmed(false), .acknowledged, .cancelled, .timedOut,
        ] {
            let text = try XCTUnwrap(json(outcome))
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
            XCTAssertNotNil(object["status"], text)
        }
    }

    func testJSONReportsCancellationAndTimeoutDistinctly() throws {
        XCTAssertEqual(json(.cancelled), "{\"status\":\"cancelled\"}")
        XCTAssertEqual(json(.timedOut), "{\"status\":\"timeout\"}")
    }

    func testJSONChoiceCarriesValuesAndIndexes() throws {
        let text = try XCTUnwrap(json(.chosen(values: ["a", "b"], indexes: [0, 3])))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        XCTAssertEqual(object["values"] as? [String], ["a", "b"])
        XCTAssertEqual(object["indexes"] as? [Int], [0, 3])
        XCTAssertEqual(object["value"] as? String, "a")
    }

    func testJSONConfirmIsABoolean() throws {
        let text = try XCTUnwrap(json(.confirmed(true)))
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        XCTAssertEqual(object["confirmed"] as? Bool, true)
    }
}

final class ChoiceOptionTests: XCTestCase {
    func testPlainOptionHasNoDetail() {
        let option = ChoiceOption(rawValue: "production")
        XCTAssertEqual(option.value, "production")
        XCTAssertNil(option.detail)
    }

    /// A tab splits value from description, because that is what cut and awk
    /// already emit.
    func testTabSplitsValueFromDetail() {
        let option = ChoiceOption(rawValue: "production\tRestarts 3 services")
        XCTAssertEqual(option.value, "production")
        XCTAssertEqual(option.detail, "Restarts 3 services")
    }

    func testOnlyTheFirstTabSplits() {
        XCTAssertEqual(ChoiceOption(rawValue: "a\tb\tc").detail, "b\tc")
    }

    func testEmptyDetailIsTreatedAsAbsent() {
        XCTAssertNil(ChoiceOption(rawValue: "production\t   ").detail)
    }
}

final class ScreenChoiceTests: XCTestCase {
    func testNamedChoices() {
        XCTAssertEqual(ScreenChoice(argument: "mouse"), .mouse)
        XCTAssertEqual(ScreenChoice(argument: "CURSOR"), .mouse)
        XCTAssertEqual(ScreenChoice(argument: "focused"), .focused)
    }

    func testDisplayIndex() {
        XCTAssertEqual(ScreenChoice(argument: "2"), .index(2))
    }

    func testRejectsNonsense() {
        XCTAssertNil(ScreenChoice(argument: "-1"))
        XCTAssertNil(ScreenChoice(argument: "left"))
    }
}
